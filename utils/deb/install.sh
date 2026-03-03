set -eu

readonly KEYRING_PATH='/usr/share/keyrings/git-secret-archive-keyring.gpg'

wget -qO - 'https://gitsecret.jfrog.io/artifactory/api/gpg/key/public' \
  | gpg --dearmor \
  | sudo tee "${KEYRING_PATH}" > /dev/null

sudo sh -c "echo 'deb [signed-by=${KEYRING_PATH}] https://gitsecret.jfrog.io/artifactory/git-secret-deb git-secret main' > /etc/apt/sources.list.d/git-secret.list"

sudo apt-get update
sudo apt-get install -y git-secret git

# Testing, that it worked:
git secret --version
