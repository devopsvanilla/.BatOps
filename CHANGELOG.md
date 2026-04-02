# Changelog

## 1.1.0 (2026-04-02)

### Features

* :sparkles: **KVM Migration**: Implementação do sistema híbrido de drivers VirtIO (Stable/Legacy).
* :sparkles: **Windows EOL**: Prompt interativo para seleção de drivers em sistemas legados (WinXP/7/2012).
* :sparkles: **UX/UI**: Geração automática de relatórios `README.txt` com comandos de importação Libvirt.
* :sparkles: **Format**: Automação de conversão para QCOW2 real com renomeação de arquivos e ajuste de XML.
* :sparkles: **Compatibility**: Suporte total ao Ubuntu 24.04 (Noble) e virt-v2v 2.4.

### Bug Fixes

* :bug: **Dependencies**: Substituição do pacote obsoleto `libguestfs-winsupport` por `ntfs-3g`.
* :bug: **Virt-v2v**: Substituição da flag legada `--virtio-win` pela variável de ambiente `VIRTIO_WIN`.
* :bug: **Shell**: Correção de avisos ShellCheck e padronização de funções (SC2218).

## 1.0.0 (2026-03-30)


### Features

* :sparkles: Add comprehensive cloud-init diagnostics script for VM status and troubleshooting ([ded2d22](https://github.com/devopsvanilla/.BatOps/commit/ded2d22bc9056ebd80c50c774330472534618404))
* :sparkles: Add detailed VM creation summary and SSH access instructions to create-proxmox-vm.sh ([6acf3c3](https://github.com/devopsvanilla/.BatOps/commit/6acf3c3f475b2f21175da85fabd95908a10d0da5))
* :sparkles: Add docker-compose and installation script for phpMyAdmin setup ([b18f24b](https://github.com/devopsvanilla/.BatOps/commit/b18f24b13ddd1fb7967a733584cbc0a6acef03bf))
* :sparkles: Add script for cleaning Morpheus Data Enterprise logs with various options ([0a81e2c](https://github.com/devopsvanilla/.BatOps/commit/0a81e2c9b9c788750dba57a511d243391d3762cb))
* :sparkles: Add script for managing logging levels and backups in Morpheus Data Enterprise ([f1f099c](https://github.com/devopsvanilla/.BatOps/commit/f1f099c969060bdda13653cc4c72d4ee251e4516))
* :sparkles: Add script to automate VM creation in Proxmox with customizable parameters and cloud-init configuration ([065abb3](https://github.com/devopsvanilla/.BatOps/commit/065abb3c6eda6248068830b270b2c46a19f711bd))
* :sparkles: Add script to detect Linux version using multiple methods ([c45a954](https://github.com/devopsvanilla/.BatOps/commit/c45a95433e462e4ea6b859e4442c2da250e34372))
* :sparkles: Add script to reset GitHub Copilot extension in VS Code ([7baba05](https://github.com/devopsvanilla/.BatOps/commit/7baba05cb59644549e9d85ed0b20c302d1d528d6))
* :sparkles: Add setup script for NFS configuration in Morpheus Data Enterprise ([c1d040c](https://github.com/devopsvanilla/.BatOps/commit/c1d040cb9a37751df58c6f4bb70fb8ae278be9d5))
* :sparkles: Add SSH diagnostics script for comprehensive troubleshooting and configuration checks ([bf1bf6d](https://github.com/devopsvanilla/.BatOps/commit/bf1bf6dabbaec0e008de48eed9b40c6aefc22008))
* :sparkles: Add SSH key selection and integration for cloud-init configuration ([4ac83df](https://github.com/devopsvanilla/.BatOps/commit/4ac83df263d3af4e4082c06da401069886586c51))
* :sparkles: Enhance cloud-init configuration with SSH and password options for improved VM setup ([6adbd2a](https://github.com/devopsvanilla/.BatOps/commit/6adbd2aa1b5f3a7e28b5aa819ab291dff0ca98a1))
* :sparkles: Enhance cloud-init configuration with SSH options and user setup ([612924f](https://github.com/devopsvanilla/.BatOps/commit/612924ff533b03ad3723472c0b60ad0ab20c468a))
* :sparkles: Enhance Morpheus log cleanup script with safe mode functionality ([72e9f47](https://github.com/devopsvanilla/.BatOps/commit/72e9f47e8067991a7de1d1d65bf772da96d570aa))
* :sparkles: Enhance phpMyAdmin installation script with improved sudo checks and user permissions handling ([5ed46d9](https://github.com/devopsvanilla/.BatOps/commit/5ed46d9fc5873b040f475face8fe215a4a0c0d89))
* :sparkles: Enhance phpMyAdmin setup script with dynamic port configuration and .env file creation ([f73c6b1](https://github.com/devopsvanilla/.BatOps/commit/f73c6b1ea8d0500d104ee38770781674ad628cd5))
* :sparkles: Enhance SSH configuration for cloud-init with password authentication and root login ([00f7d45](https://github.com/devopsvanilla/.BatOps/commit/00f7d45ede0161680d1d20187bf8687b6edfdae3))
* :sparkles: get deployment node port information ([f6d0e28](https://github.com/devopsvanilla/.BatOps/commit/f6d0e2877a8186f95327afe785704f07895bdf39))
* :sparkles: Internet Speed test added ([8f73bbe](https://github.com/devopsvanilla/.BatOps/commit/8f73bbe4d056c2df287b6994e55073265e258afe))
* :sparkles: K8S deployment samples and instructions ([569ba42](https://github.com/devopsvanilla/.BatOps/commit/569ba420d521cff1262105df56001725e603f399))
* :sparkles: Refactor MySQL password extraction and improve error messaging in phpMyAdmin setup script ([2cc76c6](https://github.com/devopsvanilla/.BatOps/commit/2cc76c6396bcf6f6c6a1c5d0f0d7437eec5ba689))
* :sparkles: script to test network connectivity ([2976638](https://github.com/devopsvanilla/.BatOps/commit/2976638c32e41b02527d9ee686b98597376dfd43))
* :sparkles: Simplify Morpheus log cleanup script by removing legacy code and focusing on UI log management ([0f78bb2](https://github.com/devopsvanilla/.BatOps/commit/0f78bb274ad37c613c2b16036cbcd808d85110d4))
* :sparkles: Update default port for phpMyAdmin setup script to 83306 and improve validation messaging ([36dd06e](https://github.com/devopsvanilla/.BatOps/commit/36dd06e7384988d7355207f280f7a46662a6917f))
* :sparkles: Update default VM password and enhance SSH configuration for improved security ([1a67cb5](https://github.com/devopsvanilla/.BatOps/commit/1a67cb5f4adcb0f2b7085116142669a2e31922fb))
* :sparkles: Update MySQL password extraction to use "root_password" key in Morpheus secrets ([50f0b59](https://github.com/devopsvanilla/.BatOps/commit/50f0b59d2161a7fe455e59bfcc0a8aab1540436c))
* :sparkles: Update phpMyAdmin port configuration to 8306 in setup script and docker-compose ([6bb1fcd](https://github.com/devopsvanilla/.BatOps/commit/6bb1fcde29910612761f54b3a11e6e957c7b0e13))
* :sparkles: Update phpMyAdmin setup script to prompt for MySQL and phpMyAdmin ports, improve validation, and create .env file with configurations ([fe45ea7](https://github.com/devopsvanilla/.BatOps/commit/fe45ea72a1b7b4913e2b5522f6e2186b49606353))
* :sparkles: Update phpMyAdmin setup script to use default port 8080 and include MySQL user configuration ([0159b0b](https://github.com/devopsvanilla/.BatOps/commit/0159b0bc62ee86aea169c3c933b44e8e06d59854))
* add .env sample ([242d701](https://github.com/devopsvanilla/.BatOps/commit/242d701788b37dd1c159527ce779101acecc04ec))
* add Docker setup for ZAP Security Scanner with comprehensive README and configuration ([853ef48](https://github.com/devopsvanilla/.BatOps/commit/853ef480319c74691eb371e639ac9225f06abda7))
* add HTTP authentication configuration to phpMyAdmin setup script for enhanced security ([5ac6534](https://github.com/devopsvanilla/.BatOps/commit/5ac653418b41bd204e807dd36b5c28bfab1b6387))
* add installer for bash scripts ([de37f6f](https://github.com/devopsvanilla/.BatOps/commit/de37f6f0f40506b9991242f7659af86f9387acf8))
* add interactive script for OWASP ZAP scanner with user prompts and validation ([2e49f04](https://github.com/devopsvanilla/.BatOps/commit/2e49f04564f99e853f327f51916b1ad9aaa3b488))
* add interactive script for SMB file sharing setup on Ubuntu ([0f8478e](https://github.com/devopsvanilla/.BatOps/commit/0f8478e46e58451764d447306ec8963869cd228a))
* add LM Audit Dashboard GUI with WPF interface and functionality ([428519f](https://github.com/devopsvanilla/.BatOps/commit/428519fd4a01106d8099ff39fb6ade06e4e63ab2))
* add operational flow diagram and detailed sequence for convert-ovf-qcow2.sh script ([2e5a7c4](https://github.com/devopsvanilla/.BatOps/commit/2e5a7c47469000617765b451f570aec7dc16aabd))
* add optional Docker network configuration and interactive deployment script for OpenLDAP stack ([f6db789](https://github.com/devopsvanilla/.BatOps/commit/f6db7891c92b43ff5a2c8d49d176de518a6927e6))
* add OVF/OVA to qcow2 conversion scripts and SMB setup utility ([efd9bfa](https://github.com/devopsvanilla/.BatOps/commit/efd9bfa3a533732b1047622f810eca5306d2570c))
* adiciona modo Local/Dummy Access com network=host ([934a286](https://github.com/devopsvanilla/.BatOps/commit/934a2864f3d1d2046df86ee27baffea523c41238))
* **copilot-reset:** add script for safe reset of GitHub Copilot in VS Code on WSL ([ba156d0](https://github.com/devopsvanilla/.BatOps/commit/ba156d0fcbf43a396a9d7d47e1add4280c2e4fd1))
* **docker-context:** add script for managing Docker contexts with user-friendly UI ([c1a4149](https://github.com/devopsvanilla/.BatOps/commit/c1a4149ffad1b819a179da69f5c3eabb8d4cf518))
* **docker-ps-all:** add script to list Docker containers across all contexts with full and simple modes ([041fbd0](https://github.com/devopsvanilla/.BatOps/commit/041fbd0628bc9dc0aa3645e426a204f17df06388))
* **docker-reset:** add comprehensive documentation for docker-reset.sh script ([0ef3c74](https://github.com/devopsvanilla/.BatOps/commit/0ef3c74d080d6eac558f65513dfcde4a3034e464))
* **docker-reset:** enhance script with dry-run option and nuclear mode for safer Docker resets ([3c8f084](https://github.com/devopsvanilla/.BatOps/commit/3c8f084609b72d8c612c602e51795cf8465a47dd))
* **docker-reset:** enhance script with options for soft cleanup and full reset of Docker ([0b84358](https://github.com/devopsvanilla/.BatOps/commit/0b843588512141c3b4f348fdd9464be39ecbd5a3))
* **docker-setup:** add installation and configuration scripts for Docker with TLS support ([d30bb9d](https://github.com/devopsvanilla/.BatOps/commit/d30bb9daf2855a8bfb3baef0c7b6ad464b0af760))
* **docker:** add docker-compose configuration for Metabase and PostgreSQL services ([d6e0728](https://github.com/devopsvanilla/.BatOps/commit/d6e0728e2587883f34c499dca928f61909c2ba65))
* enhance Docker setup for ZAP scanner with non-interactive mode and improved README ([d61f390](https://github.com/devopsvanilla/.BatOps/commit/d61f39072e46d17d4114dc3be40ee45a96767cb0))
* enhance phpMyAdmin setup script to configure HTTP authentication using native openssl without additional installations ([7d1f6cc](https://github.com/devopsvanilla/.BatOps/commit/7d1f6cc49f0d599549ea3cf721102e49564ab735))
* enhance phpMyAdmin setup script with improved prompts and MySQL configuration for external connections ([fc24853](https://github.com/devopsvanilla/.BatOps/commit/fc24853535173e5af9cacb06eafd2670f53971fa))
* enhance ZAP scanner documentation and scripts for non-public domain support ([aab0bd8](https://github.com/devopsvanilla/.BatOps/commit/aab0bd8444ad4a9243e664899eb678eb09c143bf))
* **find-dir-term:** add script to find directories matching a specified term with unique output ([dddb481](https://github.com/devopsvanilla/.BatOps/commit/dddb4814920658cfecdeced3793610944b8aa5c1))
* improve troubleshooting documentation and enhance Docker command handling in scripts ([6a2c1bb](https://github.com/devopsvanilla/.BatOps/commit/6a2c1bb7d8c058acaa3683332623c7292b6249d2))
* **kubeadm:** add API access validation to get-credential.sh script ([b583fda](https://github.com/devopsvanilla/.BatOps/commit/b583fdafbdb8ef76a915ec2db32c65eea314b048))
* **kubeadm:** add init-master script and update install-requirements for improved Kubernetes setup ([8074455](https://github.com/devopsvanilla/.BatOps/commit/80744551dde569a20ae70b16c28c32317a914424))
* **kubeadm:** add installation script for Kubernetes on Ubuntu 24.04 LTS ([121628c](https://github.com/devopsvanilla/.BatOps/commit/121628cd852b9ad1bd9c41d36911e53612b33103))
* **kubeadm:** add upgrade orchestration scripts and documentation for safe Kubernetes upgrades ([3eb05c3](https://github.com/devopsvanilla/.BatOps/commit/3eb05c3a31eac75a378f7b7882f8d160bc515f4d))
* **kubeadm:** enhance get-credential.sh to output API token and kubeconfig in separate blocks ([0344855](https://github.com/devopsvanilla/.BatOps/commit/034485507ddb6490220038b35e00164856502dda))
* **kubeadm:** enhance installation script with existing installation detection and update options ([d19544b](https://github.com/devopsvanilla/.BatOps/commit/d19544ba2fb7d8b4a9c9135ec1602bc698f2f405))
* **kubeadm:** enhance installation script with kubeadm reset and cleanup procedures ([618221e](https://github.com/devopsvanilla/.BatOps/commit/618221e2608692bdadd34749a8664dae88c55deb))
* **kubeadm:** enhance installation script with process termination and network cleanup during reset ([910b2c4](https://github.com/devopsvanilla/.BatOps/commit/910b2c406efbb0840a6a9163bef86e17454ed8a2))
* **kubeadm:** enhance README and add get-credential.sh for improved Kubernetes credential management ([56cc811](https://github.com/devopsvanilla/.BatOps/commit/56cc81107d35c3619be4796a5c35b9ec45508134))
* **kubeadm:** remove deprecated get-credential.sh script and usage guide ([f7c1df7](https://github.com/devopsvanilla/.BatOps/commit/f7c1df7e91d491362db191a686aef9843441f7d1))
* **kubeadm:** update README and add scripts for Kubernetes setup, including kubectl configuration and Flannel installation ([0879018](https://github.com/devopsvanilla/.BatOps/commit/08790183b7d392cbc79717d761fe3be72825cbf6))
* **kubeadm:** update README and scripts for improved Kubernetes setup clarity and security ([54ad1d3](https://github.com/devopsvanilla/.BatOps/commit/54ad1d3eeb7c0b2f00a40f6d24db1dbc24c891e6))
* **logitech-mxkeys:** add script to configure Logitech MX Keys on Ubuntu with locale and keyboard layout settings ([4db2d1f](https://github.com/devopsvanilla/.BatOps/commit/4db2d1f677dca0ff022e79a77e90a3be9fee10c1))
* **logitech-mxkeys:** apply US keyboard layout configuration for console and X11 with persistent settings ([5bcd8ad](https://github.com/devopsvanilla/.BatOps/commit/5bcd8ad713f0eb892058dc50d4f270ab22e69def))
* **logitech-mxkeys:** create template .Xmodmap for custom key mapping of ç ([65de960](https://github.com/devopsvanilla/.BatOps/commit/65de96027b79200aae8d75bdc63580e3badaeddf))
* **logitech-mxkeys:** update keyboard layout configuration and add custom key mapping for ç ([51d3cf2](https://github.com/devopsvanilla/.BatOps/commit/51d3cf2927073569fa9cfd3c52d236caa7dfc7fb))
* **logitech-mxkeys:** update keyboard layout configuration and custom key mapping for ç with AltGr+c ([63b0fdb](https://github.com/devopsvanilla/.BatOps/commit/63b0fdb39f30b9f6cf88693ea494e85ca905263a))
* **mssql+sqlpad:** add initial setup for Microsoft SQL Server and SQLPad with environment configuration ([380e7b0](https://github.com/devopsvanilla/.BatOps/commit/380e7b0c65aa193f526fff020180a3f1b9d38745))
* **mssql+sqlpad:** automatiza redeploy e reset de volumes ([fda1de3](https://github.com/devopsvanilla/.BatOps/commit/fda1de386df8337ce083075390e56c6c752f41c8))
* **openldap+phpLDAPadmin:** add Docker Compose setup with environment configuration and documentation ([4d5f6a7](https://github.com/devopsvanilla/.BatOps/commit/4d5f6a70773bcef647987f311b43821723c9aebc))
* **portainer:** Add comprehensive troubleshooting documentation and setup scripts ([a27b44d](https://github.com/devopsvanilla/.BatOps/commit/a27b44d649e4708fbb80fdf2b403074e97b8520d))
* **remote-setup:** add Docker network selection validation and update documentation ([33e0a64](https://github.com/devopsvanilla/.BatOps/commit/33e0a647ddc7209a5f700439bef3057577df14cc))
* **remote-setup:** valida filesystem e permissões ([6a19fad](https://github.com/devopsvanilla/.BatOps/commit/6a19faddfd5e3264fd7e4e402bfa09a1d265ff06))
* remove version specification from docker-compose.yml for improved compatibility ([233e058](https://github.com/devopsvanilla/.BatOps/commit/233e0584ab7f32dc6dc21da974bd4e14f5b9c47a))
* **repo:** padronização do monorepo e correção de falhas de pre-commit ([051cee5](https://github.com/devopsvanilla/.BatOps/commit/051cee5cedc8c731b97409525ecc44b9ba3f2ef1))
* restore docker-compose configuration for phpMyAdmin setup ([474993e](https://github.com/devopsvanilla/.BatOps/commit/474993e2fa19e67e883e94d9aec5fcb1368c2735))
* **setup-remote-docker:** enhance remote Docker setup with SSH password support and certificate management ([869abbe](https://github.com/devopsvanilla/.BatOps/commit/869abbeff1f5a404a8ade750b3902550fcd3b9d6))
* **setup-remote-docker:** enhance script with Docker context management and environment variable cleanup ([60154a3](https://github.com/devopsvanilla/.BatOps/commit/60154a34bf8a231f727b68cda6fbeb1ab429b9e3))
* solução para conversão de imagens do vmware para kvm ([4300766](https://github.com/devopsvanilla/.BatOps/commit/43007664f4df59080ba652fba6acc9d8cc876549))
* **starship-install:** add installation script for Starship Prompt on Ubuntu with configuration setup ([00a8d53](https://github.com/devopsvanilla/.BatOps/commit/00a8d534caffc1fb18cb7c220315610d2e2ce7f4))
* update phpMyAdmin configuration to use dynamic host IP and adjust port prompts ([1c27cd6](https://github.com/devopsvanilla/.BatOps/commit/1c27cd62c14b577fcdf9b70c88685c0a68f2f3d8))
* update phpMyAdmin configuration to use host network mode and adjust environment variables for localhost access ([5f0c9ad](https://github.com/devopsvanilla/.BatOps/commit/5f0c9ad1b9fbd59a1add0c696820fcfff6dacfb2))
* update phpMyAdmin setup script to enhance user prompts and configure MySQL permissions for external connections ([332c2bc](https://github.com/devopsvanilla/.BatOps/commit/332c2bc81413134bddba3c7b9faaf463f3f6b0ed))
* update phpMyAdmin setup to use default port 8080 and adjust docker-compose configuration ([456ff13](https://github.com/devopsvanilla/.BatOps/commit/456ff13b27de996223a0a1af450bcaf41514f51f))
* update phpMyAdmin setup to use port 8306 and adjust MySQL port prompts ([6db9461](https://github.com/devopsvanilla/.BatOps/commit/6db94613aff28e51bb9eab3be16c2ee5df2d40e9))
* ZAP tests and docs ([e85dd00](https://github.com/devopsvanilla/.BatOps/commit/e85dd00a8e11d698e6d09a545aac744285b80183))


### Bug Fixes

* :bug: Correct default gateway IP address in create-proxmox-vm.sh script ([8a20efc](https://github.com/devopsvanilla/.BatOps/commit/8a20efc7a9499adf86d208898f324e3f8154a77b))
* :bug: Correct default VM username typo and update cloud-init user password handling ([3af8c7c](https://github.com/devopsvanilla/.BatOps/commit/3af8c7c8d81b3a273b7356d31489e05d29bc13ca))
* :bug: Correct VGA configuration to use Standard VGA in create-proxmox-vm.sh ([f8877a0](https://github.com/devopsvanilla/.BatOps/commit/f8877a097759741333313625ca775cd05d7053c7))
* atualiza script de debug com correção de stderr ([aab2d01](https://github.com/devopsvanilla/.BatOps/commit/aab2d0169c630233d557eaadf32f6eeee946e854))
* corrige captura de stdout na função get_host_entries ([686830d](https://github.com/devopsvanilla/.BatOps/commit/686830dab5758b60b25b29ee4adb6f09de178690))
* Corrige install-docker-remote.sh para copiar certificados para o usuário correto ([17b6892](https://github.com/devopsvanilla/.BatOps/commit/17b6892c829980e8cb0e8e52393e1a4a863d90cf))
* create folders required in VWmare Convertion tool ([23152f7](https://github.com/devopsvanilla/.BatOps/commit/23152f764a99d5907227b77399d24c8c765d819e))
* quote host entries variable in Docker run command for proper handling ([e77ebb9](https://github.com/devopsvanilla/.BatOps/commit/e77ebb9e20769e736e84b1167a6346285a241228))
* remove aspas da variável host_entries para expansão correta ([29d2c81](https://github.com/devopsvanilla/.BatOps/commit/29d2c81efcaaa21d911ca8cea2396c22231c7968))
* simplifica arquitetura removendo container intermediário ([78bc01d](https://github.com/devopsvanilla/.BatOps/commit/78bc01d04f11dbbe414efb2e5e4a5c166f453fd6))
* update flowchart labels for clarity in README.md ([14f5a0c](https://github.com/devopsvanilla/.BatOps/commit/14f5a0c3e179c9b8428a96b8a366c114a60ba91b))
