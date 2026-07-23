#!/bin/bash
set -e
IMAGE_NAME="mysql-compiler"
CONTAINER_NAME="temp-mysql-builder"
LOCAL_DEST="./mysql-dist" # Pasta que você moverá para o servidor

docker build -t $IMAGE_NAME .
docker rm -f $CONTAINER_NAME || true
docker run --name $CONTAINER_NAME $IMAGE_NAME

echo "💾 Extraindo pacote completo (binário + libs + terminfo)..."
rm -rf $LOCAL_DEST
mkdir -p $LOCAL_DEST
docker cp $CONTAINER_NAME:/root/build/mysql-portable/ $LOCAL_DEST/

# Cria o script wrapper dentro da pasta para o usuário usar
cat <<EOF > $LOCAL_DEST/mysql-portable/run.sh
#!/bin/bash
BASE_DIR=\$(dirname "\$0")
export LD_LIBRARY_PATH="\$BASE_DIR/lib:\$LD_LIBRARY_PATH"
export TERMINFO="\$BASE_DIR/terminfo"
"\$BASE_DIR/mysql" "\$@"
EOF
chmod +x $LOCAL_DEST/mysql-portable/run.sh

docker rm $CONTAINER_NAME
echo "✅ Pacote pronto em: $LOCAL_DEST/mysql-portable/"
