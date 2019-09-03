#!/bin/bash

pause() {
  read -n1 -r -p "Press space/enter to continue, any other key to cancel..." key    
  if [ "$key" = '' ]; then
    echo ""
  else
    echo "Cancelled"
    exit 1
  fi
}

gqc New content
stack build ; stack exec blog clean ; stack exec blog build
pause
echo continue

git fetch --all ; git checkout -b master --track origin/master
pause

cp -a _site/. .

# TODO hakyll
mkdir _site/site
cp site/favicon.ico _site/site/

git config user.name "leigh-perry" ; git config user.email "lperry.breakpoint@gmail.com" ; gs ; gqc "Publish"
git push origin master:master
pause

git checkout develop ; git branch -D master
pause

git push

open https://leigh-perry.github.io