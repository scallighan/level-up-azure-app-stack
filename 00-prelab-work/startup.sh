#!/bin/bash
mkdir /levelup
cd /levelup
echo "Cloning repository... https://github.com/$GH_REPO.git"
git clone https://github.com/$GH_REPO.git
nginx -g "daemon off;"
