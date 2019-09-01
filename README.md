# Deployment

gqc New content
stack build ; stack exec blog clean ; stack exec blog build

git fetch --all ; git checkout -b master --track origin/master

cp -a _site/. .
gqc Publish
git push origin master:master
git checkout develop ; git branch -D master
git push
