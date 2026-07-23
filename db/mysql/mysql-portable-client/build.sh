#!/bin/bash
set -e

# Variáveis de configuração
MYSQL_VERSION="8.0.36"
BOOST_VERSION="1_77_0"
SRC_DIR="mysql-${MYSQL_VERSION}"
BUILD_DIR="mysql-build-portable"
INSTALL_DIR="$(pwd)/mysql-portable"
ABS_SRC_DIR="$(pwd)/${SRC_DIR}"
BOOST_PATH="$(pwd)/${BUILD_DIR}/boost/boost_${BOOST_VERSION}"

echo "🚀 Iniciando processo de compilação e empacotamento..."

# 1. Download e Extração
if [ ! -d "$SRC_DIR" ]; then
    wget -c "https://dev.mysql.com/get/Downloads/MySQL-${MYSQL_VERSION%.*}/mysql-${MYSQL_VERSION}.tar.gz"
    tar -xzf "mysql-${MYSQL_VERSION}.tar.gz"
fi

# 2. Preparação do Build
rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Boost (obrigatório para MySQL)
mkdir -p boost
if [ ! -d "boost/boost_${BOOST_VERSION}" ]; then
    wget -c "https://archives.boost.io/release/1.77.0/source/boost_${BOOST_VERSION}.tar.bz2" -P boost/
    tar -xf "boost/boost_${BOOST_VERSION}.tar.bz2" -C boost/
fi

# 3. Configuração e Compilação
cmake "$ABS_SRC_DIR" \
  -Wno-dev \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DWITH_SSL=system \
  -DWITH_ZLIB=bundled \
  -DWITH_EDITLINE=bundled \
  -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
  -DWITH_BOOST="$BOOST_PATH" \
  -DWITH_UNIT_TESTS=OFF \
  -DFORCE_INSOURCE_BUILD=0

make mysql -j"$(nproc)"

# 4. Extração e Coleta de Dependências (Runtime)
mkdir -p "$INSTALL_DIR/lib"
mkdir -p "$INSTALL_DIR/terminfo"

# Copia o binário
cp "$(find . -name mysql -type f -executable | head -n 1)" "$INSTALL_DIR/"

echo "📦 Coletando bibliotecas e terminfo..."
# Localiza e copia bibliotecas dinâmicas necessárias
for lib in libtinfo.so.6 libncurses.so.6; do
    LIB_PATH=$(find /lib /usr/lib -name "$lib" | head -n 1)
    [ -n "$LIB_PATH" ] && cp "$LIB_PATH" "$INSTALL_DIR/lib/"
done

# Copia terminfo
TERMINFO_PATH=$(find /usr/share/terminfo /lib/terminfo -type d -name "terminfo" | head -n 1)
[ -n "$TERMINFO_PATH" ] && cp -r "$TERMINFO_PATH/"* "$INSTALL_DIR/terminfo/"

# Cria o script wrapper portátil
cat <<EOF > "$INSTALL_DIR/run.sh"
#!/bin/bash
BASE_DIR=\$(dirname "\$0")
export LD_LIBRARY_PATH="\$BASE_DIR/lib:\$LD_LIBRARY_PATH"
export TERMINFO="\$BASE_DIR/terminfo"
"\$BASE_DIR/mysql" "\$@"
EOF
chmod +x "$INSTALL_DIR/run.sh"

echo "✅ Pacote pronto em: $INSTALL_DIR"
