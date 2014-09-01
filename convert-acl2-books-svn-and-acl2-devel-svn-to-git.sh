#!/bin/bash

# Before running this script repeatedly, you need to:
# (1) mirror the google code repositories and
# (2) create an authors file for mapping svn authors to git authors

# Details on (1):

cd ~/svn-to-git # working directory, maybe should be parameterized

svnadmin create acl2-books-svn-sync
svnadmin create acl2-devel-svn-sync

# for each repo, put #/bin/sh in the file hooks/pre-revprop-change and
# make it executable

# The below echo's don't work because the escaping is messed up, so we cp it.
#echo "#!/bin/sh" > acl2-devel-svn-sync/hooks/pre-revprop-change
cp pre-revprop-change acl2-devel-svn-sync/hooks/
chmod 755 acl2-devel-svn-sync/hooks/pre-revprop-change

#echo "#!/bin/sh" > acl2-books-svn-sync/hooks/pre-revprop-change
cp pre-revprop-change acl2-books-svn-sync/hooks/
chmod 755 acl2-books-svn-sync/hooks/pre-revprop-change


echo "=== Creating initial svn repositories"
svnsync init file:///home/ragerdl/svn-to-git/acl2-devel-svn-sync http://acl2-devel.googlecode.com/svn 
svnsync init file:///home/ragerdl/svn-to-git/acl2-books-svn-sync http://acl2-books.googlecode.com/svn 

echo "=== Sync'ing intial svn repositories (takes awhile)"
svnsync sync file:///home/ragerdl/svn-to-git/acl2-devel-svn-sync
svnsync sync file:///home/ragerdl/svn-to-git/acl2-books-svn-sync


# Details on (2):

# From a svn working copy (of either the merged repo or of the googlecode repos):
# svn log ^/ --xml | grep -P "^<author" | sort -u | perl -pe 's/<author>(.*?)<\/author>/$1 = /' > authors.txt

# Then fill in the blanks where the RHS is <github-username> <github email address>
# You'll need to add a record for the "(no author)" entry.  Append this to the end:
# (no author) = No Author <noauthor@invalidemailaddress.com>

# Essay/reflection: Why can't we just do something like
# http://ericlathrop.com/2014/01/combining-git-repositories/ ?  We
# made all of these "branches" in acl2-books that aren't really
# supposed to be branches.  Really, they should be tags.  People can
# create their own branches from these tags if they wish, but our repo
# should have tags.  Maybe we should move these branches to tags in a
# subversion repository, but really, we just want to smash them and
# start over.  Also, the use of acl2svn/trunk is weird, and I'm hoping
# that I can rewrite that history too.

# Ah ha!  But, we could just commit them for now and then nuke/prune
# them later, after we've already combined both repos.

cd /home/ragerdl/svn-to-git # working directory
mkdir logs

echo "===getting the latest versions of the acl2-devel and acl2-books repos (< 30 sec)"
# Why do we grab the entire contents of the repos, and not just the
# trunks?  We want to capture as much history as possible, and then
# we're going to get rid of the branches and tags.  It might be
# possible to do this more quickly without such history (it would
# certainly be faster), but Rager thought this through at some point,
# and he thought it would be better this way.
svnsync sync file:///home/ragerdl/svn-to-git/acl2-devel-svn-sync
svnsync sync file:///home/ragerdl/svn-to-git/acl2-books-svn-sync

echo "===removing dumps in 5 seconds"
sleep 5
rm -rf dumps

echo "===creating dumps (4 min on SSD)"
mkdir dumps
time svnadmin dump acl2-devel-svn-sync > dumps/acl2-devel.dmp
time svnadmin dump acl2-books-svn-sync > dumps/acl2-books.dmp


echo "===removing combined-svn and combined-svn-wc in 5 seconds"
sleep 5
rm -rf combined-svn
rm -rf combined-svn-wc

echo "===creating temporary combined svn repo"
svnadmin create combined-svn
svn co file:///home/ragerdl/svn-to-git/combined-svn combined-svn-wc
pushd combined-svn-wc
mkdir books
svn add books --force
svn commit -m "Added initial project directories."
popd

echo "===loading dumps into repository (~11 min on SSD)"
time svnadmin load combined-svn < dumps/acl2-devel.dmp
time svnadmin load combined-svn --parent-dir books < dumps/acl2-books.dmp

echo "===checking out working copy of merged svn repo (56  min)"
time svn co file:///home/ragerdl/svn-to-git/combined-svn combined-svn-wc --ignore-externals > logs/checkout.log
echo "===removing branches and tags from working copy of merged svn repo (<3 min)"
pushd combined-svn-wc
time svn rm branches wiki tags acl2svn > ../logs/remove-branches-and-tags.log
#svn rm tags >> ../logs/remove-branches-and-tags.log
time svn rm books/branches books/tags books/jenkins books/wiki >> ../logs/remove-branches-and-tags.log
#svn rm books/tags >> ../logs/remove-branches-and-tags.log

echo "===commiting removed branches and tags from working copy of merged svn repo (14 min)"
time svn commit -m "Removing legacy branches and tags" >> ../logs/remove-branches-and-tags.log
popd


echo "===creating git version of combined svn repo (63 min)"
time git svn clone file:///home/ragerdl/svn-to-git/combined-svn combined-svn.git --authors-file=authors.txt --no-metadata > logs/combined-svn.git.log # do not use -s option

# The following four calls of git filter-branch should work (infact,
# the first two seem to have already worked).  However, filter-branch
# is really slow.  As such, we use the bfg tool instead.  Searching
# for "git bfg" yields lots of hits.

# echo "===removing acl2svn/branches from the repo (33 min)"
# time git filter-branch --force --index-filter \
# 'git rm -r --cached --ignore-unmatch acl2svn/branches' \
# --prune-empty --tag-name-filter cat -- --all > removing-branches-and-tags.log

# echo "===removing acl2svn/tags from the repo (27 min when second)"
# time git filter-branch --force --index-filter \
# 'git rm -r --cached --ignore-unmatch acl2svn/tags' \
# --prune-empty --tag-name-filter cat -- --all >> removing-branches-and-tags.log

# echo "===removing books/branches from the repo (probably around 20 hours)"
# git filter-branch --force --index-filter \
# 'git rm -r --cached --ignore-unmatch books/branches' \
# --prune-empty --tag-name-filter cat -- --all >> removing-branches-and-tags.log

# echo "===removing books/tags from the repo (didn't test)"
# git filter-branch --force --index-filter \
# 'git rm -r --cached --ignore-unmatch books/tags' \
# --prune-empty --tag-name-filter cat -- --all >> removing-branches-and-tags.log

# REMEMBER TO REMOVE THE -NEW-AUTHORS BELOW
#cd combined-svn.git

# I don't need to remove branches and tags from HEAD with git, because
# we removed them from the subversion repo above.
# cp -pR combined-svn.git combined-svn-no-branches-or-tags.git
# cd combined-svn-no-branches-or-tags.git
# git rm -r branches > ../removing-branches-and-tags.log
# git rm -r books/branches >> ../removing-branches-and-tags.log
# git rm -r books/tags >> ../removing-branches-and-tags.log
# git rm -r books/jenkins >> ../removing-branches-and-tags.log
# git rm -r books/wiki >> ../removing-branches-and-tags.log
# git commit -a -m "Removing branches and tags from HEAD so we can cleanup the repository."
# cd ..

alias bfg='java -jar bfg-1.11.7.jar'
rm -rf combined-svn-no-branches-or-tags.git
echo "===cloning combined-svn.git"
git clone combined-svn.git combined-svn-no-branches-or-tags.git

# We need to remove all pointers from HEAD to the branches and tags,
# or else bfg will consider the branches and tags "protected" and skip
# them.


# I ran "find . -name 'branches'" in a checkout of acl2-devel trunk
# and saw that there were no hits.  As such, it is safe to run the
# following command.  Also, -p protects us.
echo "===bfg'ing branches"
bfg --delete-folders branches combined-svn-no-branches-or-tags.git #--no-blob-protection #-p HEAD,refs/heads/master

# I ran "find . -name 'tags'" in a checkout of acl2-devel trunk
# and saw that there were no hits.  As such, it is safe to run the
# following command.  Also, -p protects us.
echo "===bfg'ing tags"
bfg --delete-folders tags combined-svn-no-branches-or-tags.git #--no-blob-protection #-p HEAD,refs/heads/master

echo "===gc'ing bfg'd stuff (3 min)"
pushd combined-svn-no-branches-or-tags.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive
popd

# don't need to do this -- we'll just use combined-svn-no-branches-or-tags.git
# pushd ../combined-svn.git
# git checkout -b deletethis
# popd
# git config receive.denyCurrentBranch warn
# git push
# pushd ../combined-svn.git
# git branch delete -D deletethis
# popd
# cd ..

rm -rf combined-svn-rewritten-devel-and-books.git
cp -pR combined-svn-no-branches-or-tags.git combined-svn-rewritten-devel-and-books.git
pushd combined-svn-rewritten-devel-and-books.git


echo "===rewriting acl2svn history from very old commits (16 min on SSD)"
echo "===disregard the errors about being unable to move .."
time git filter-branch -f --tree-filter 'test -d acl2svn/trunk && mv acl2svn/trunk/* acl2svn/trunk/.[^.]* . || echo "Nothing to do"' HEAD

# rewrite system history -- must be done after the acl2svn history
echo "===rewriting system history (24 min on SSD)"
echo "===disregard the errors about being unable to move .."
time git filter-branch -f --tree-filter 'test -d trunk && mv trunk/* trunk/.[^.]* . || echo "Nothing to do"' HEAD

echo "===rewriting books history (163 min on SSD)"
echo "===disregard the errors about being unable to move .."
time git filter-branch -f --tree-filter 'test -d books/trunk && mv books/trunk/* books/trunk/.[^.]* ./books || echo "Nothing to do"' HEAD
popd


cp -pR combined-svn-rewritten-devel-and-books.git combined-svn-rewritten-devel-and-books-pruned.git

pushd combined-svn-rewritten-devel-and-books-pruned.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git --no-pager log --format='%at %H' master > ../combined-commits.log
popd

cat combined-commits.log | sort | cut -d' ' -f2 \
    > ordered-commits.log

rm -rf combined-better-history.git
git init combined-better-history.git
pushd combined-better-history.git
# if we don't commit a temporary file, the cherry-pick below fails
touch temp-temp.txt
git add temp-temp.txt
git commit -m "temporary commit"
git rm temp-temp.txt
git commit -m "remove temporary file"

git remote add unordered ../combined-svn-rewritten-devel-and-books-pruned.git
git fetch unordered
cat ../ordered-commits.log | while read commit; do git cherry-pick --allow-empty --allow-empty-message $commit; done
popd

rm -rf target.git
cp -pR combined-better-history.git target.git
pushd target.git

git remote remove unordered
git remote add origin https://github.com/acl2/acl2.git
git push -u origin master
