Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,System.Windows.Forms

# ================== CONFIG PADRÃO ==================
$LM_BASE = "http://127.0.0.1:1234/v1/chat/completions"
$MODEL   = "qwen2.5-coder-7b-instruct"
$MAX_JOB_CONCURRENCY = 6

# ================== GERADOR WPF ==================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="LM Studio Audit Dashboard" Height="560" Width="740" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Configurações -->
        <StackPanel Grid.Row="0" Orientation="Vertical" Margin="0,0,0,10">

            <TextBlock FontSize="20" FontWeight="Bold">LM Studio Audit Dashboard (GUI)</TextBlock>
            <Separator/>

            <StackPanel Orientation="Horizontal">
                <TextBlock Text="Estilo:" Width="160"/>
                <ComboBox Name="StyleBox" Width="220">
                    <ComboBoxItem Content="Minimal" Tag="1"/>
                    <ComboBoxItem Content="Dark" Tag="2"/>
                    <ComboBoxItem Content="Cyberpunk" Tag="3"/>
                    <ComboBoxItem Content="Modern" Tag="4"/>
                </ComboBox>
            </StackPanel>

            <StackPanel Orientation="Horizontal">
                <TextBlock Text="Visualização:" Width="160"/>
                <ComboBox Name="ViewBox" Width="220">
                    <ComboBoxItem Content="Accordion" Tag="A"/>
                    <ComboBoxItem Content="Tabela+Modal" Tag="B"/>
                    <ComboBoxItem Content="Expandido" Tag="C"/>
                </ComboBox>
            </StackPanel>

            <StackPanel Orientation="Horizontal">
                <TextBlock Text="Formato do relatório:" Width="160"/>
                <ComboBox Name="FormatBox" Width="220">
                    <ComboBoxItem Content="Estruturado" Tag="I"/>
                    <ComboBoxItem Content="Texto-livre" Tag="II"/>
                    <ComboBoxItem Content="Ambos" Tag="III"/>
                </ComboBox>
            </StackPanel>

            <StackPanel Orientation="Horizontal">
                <TextBlock Text="Execução paralela?" Width="160"/>
                <CheckBox Name="ParallelBox"/>
            </StackPanel>

            <StackPanel Orientation="Horizontal">
                <TextBlock Text="Gerar JSON?" Width="160"/>
                <CheckBox Name="JsonBox" IsChecked="True"/>
            </StackPanel>

            <StackPanel Orientation="Horizontal">
                <TextBlock Text="Diretório alvo:" Width="160"/>
                <TextBox Name="DirBox" Width="370"/>
                <Button Name="BrowseBtn" Width="80" Margin="5,0,0,0">Selecionar</Button>
            </StackPanel>

        </StackPanel>

        <!-- Log -->
        <TextBox Grid.Row="1" Name="LogBox" Margin="0,0,0,10" 
                 IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>

        <!-- Ações -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
            <ProgressBar Name="Prog" Width="250" Height="20" Margin="0,0,10,0"/>
            <Button Name="RunBtn" Width="140" Height="30">Iniciar Auditoria</Button>
        </StackPanel>

    </Grid>
</Window>
"@

# ========== LOADING WPF =============
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Bindings
$StyleBox = $window.FindName("StyleBox")
$ViewBox  = $window.FindName("ViewBox")
$FormatBox= $window.FindName("FormatBox")
$ParallelBox= $window.FindName("ParallelBox")
$JsonBox  = $window.FindName("JsonBox")
$DirBox   = $window.FindName("DirBox")
$BrowseBtn= $window.FindName("BrowseBtn")
$RunBtn   = $window.FindName("RunBtn")
$LogBox   = $window.FindName("LogBox")
$Prog     = $window.FindName("Prog")

# ========== HELPERS =============
function Log {
    param([string]$msg)
    $LogBox.AppendText("$msg`n")
    $LogBox.ScrollToEnd()
}

function Invoke-LMQuery($filePath, $content, $format) {

    $header = @"
Analise este arquivo e descreva:
- Acessos externos
- Dependências remotas
- Riscos de segurança
- Rastreadores
- Recomendações
Arquivo: $filePath
"@

    switch ($format) {
        "I" { $bodyText = "$header`nFormato estruturado:`n$content" }
        "II" { $bodyText = "$header`nTexto livre:`n$content" }
        "III" { $bodyText = "$header`nEstruturado + livre:`n$content" }
    }

    $body = @{
        model = $MODEL
        messages = @(
            @{ role = "user"; content = $bodyText }
        )
    } | ConvertTo-Json -Depth 8

    try {
        return Invoke-RestMethod -Method Post -Uri $LM_BASE -Body $body -ContentType "application/json"
    } catch {
        return @{ error = $_.Exception.Message }
    }
}

# ========== BROWSE =============
$BrowseBtn.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dlg.ShowDialog() -eq "OK") {
        $DirBox.Text = $dlg.SelectedPath
    }
})

# ========== RUN =============
$RunBtn.Add_Click({

    $style = $StyleBox.SelectedItem.Tag
    $view = $ViewBox.SelectedItem.Tag
    $format = $FormatBox.SelectedItem.Tag
    $parallel = $ParallelBox.IsChecked
    $json = $JsonBox.IsChecked
    $dir = $DirBox.Text

    if (-not (Test-Path $dir)) {
        Log "❌ Diretório inválido."
        return
    }

    Log "📁 Coletando arquivos..."
    $patterns = "*.py","*.js","*.ts","*.tsx","*.jsx","*.html","*.css","*.json","Dockerfile","*.sh","*.env","*.ini"

    $files = @()
    foreach ($p in $patterns) {
        $files += Get-ChildItem -Path $dir -Recurse -File -Filter $p -ErrorAction SilentlyContinue
    }

    if ($files.Count -eq 0) {
        Log "❌ Nenhum arquivo encontrado."
        return
    }

    Log "🔍 $($files.Count) arquivos encontrados."

    $timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")
    $results = @()

    $Prog.Minimum = 0
    $Prog.Maximum = $files.Count
    $Prog.Value = 0

    if ($parallel) {

        Log "⚡ Executando em paralelo..."

        $jobs = foreach ($f in $files) {
            Start-Job -ScriptBlock {
                param($fp, $MODEL, $LM_BASE)

                try { $content = Get-Content $fp -Raw }
                catch { return @{ file=$fp; text=$_ } }

                $body = @{
                    model = $MODEL
                    messages = @(
                        @{ role="user"; content="Analise este arquivo: $fp`n$content" }
                    )
                } | ConvertTo-Json -Depth 8

                try {
                    $r = Invoke-RestMethod -Method Post -Uri $LM_BASE -Body $body -ContentType "application/json"
                    return @{ file=$fp; text=$r.choices[0].message.content }
                } catch {
                    return @{ file=$fp; text="erro: $_" }
                }

            } -ArgumentList $f.FullName, $MODEL, $LM_BASE
        }

        while ($jobs.State -contains "Running") {
            $done = ($jobs | Where-Object { $_.State -eq "Completed" }).Count
            $Prog.Value = $done
            Start-Sleep -Milliseconds 300
        }

        foreach ($j in $jobs) {
            $r = Receive-Job $j
            $results += $r
            Remove-Job $j
        }

    } else {

        Log "🐢 Executando sequencialmente..."

        foreach ($f in $files) {
            Log "→ $($f.FullName)"
            try { $content = Get-Content -Raw -LiteralPath $f.FullName } catch { continue }

            $resp = Invoke-LMQuery $f.FullName $content $format
            $txt = if ($resp.error) { $resp.error } else { $resp.choices[0].message.content }

            $results += @{ file=$f.FullName; text=$txt }

            $Prog.Value += 1
        }
    }

    # --- JSON ---
    if ($json) {
        $jsonPath = "audit_$timestamp.json"
        $results | ConvertTo-Json -Depth 10 | Out-File $jsonPath -Encoding UTF8
        Log "📄 JSON gerado: $jsonPath"
    }

    # --- HTML ---
    $html = "audit_$timestamp.html"

    $cards = ""
    foreach ($r in $results) {
        $cards += "<h3>$($r.file)</h3><pre>$([System.Web.HttpUtility]::HtmlEncode($r.text))</pre><hr/>"
    }

    $out = @"
<html><body>
<h1>Audit Report - $timestamp</h1>
$cards
</body></html>
"@

    $out | Out-File $html -Encoding UTF8
    Log "🌐 HTML gerado: $html"

    Log "✅ Finalizado!"
})

# ========== RUN WINDOW ==========
$window.ShowDialog() | Out-Null
