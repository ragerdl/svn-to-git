#!/bin/bash

# 1. Perform an "everything" build.  If it fails once because of some
# quicklisp thing, just run it again.  If it turns out there really
# was a problem with the conversion of the quicklisp code, we can
# figure out how to patch it afterwards.  That would be a small problem.

# 2. Compare every file that isn't .svn, .git, or .gitignore.

svn co -q http://acl2-devel.googlecode.com/svn/trunk acl2-qa.svn
git clone http://github.com/acl2/acl2-defthm-rc1 acl2-qa.git

cat qa-extensions.txt | while read ext; do
  cd acl2-qa.svn
  svncount=`find . -name "*.$ext" | wc -l`
  cd ../acl2-qa.git
  gitcount=`find . -name "*.$ext" | wc -l`
  cd ..
  if [ $svncount -eq $gitcount ]; then
    echo "count match for *.$ext"
  else
    echo "*** count mismatch for $.ext***"
    echo "svncount for *.$ext is: $svncount"
    echo "gitcount for *.$ext is: $gitcount"

  fi;
done

# We can omit anything that reads "only in", because we've already
# done a pretty darn good check (read: not perfect, but certainly good
# enough for our task) that all files that we care about are in both
# directories.
echo ""
echo "===Inspect the following to make sure that you are okay with the differences."
echo "It is a recursive diff between the svn and git repos, ignoring .svn files"
echo "and files or directories that were only in one of them."
echo "We use the count check above to approximately ensure that we're not missing"
echo "any files.  Thus, it is reasonable to omit directories that differ."
echo "(git doesn't allow empty directories.)"
echo ""

diff -B -r acl2-qa.svn acl2-qa.git | grep -v ".svn" | grep -v "Only in"


echo ""
echo "You'll also want to inspect the gitk history and see that it makes sense."
echo "Note that with the exception of two initial commits, all of them are ordered"
echo "by timestamp (OooOOOoo ahhhhhhh)."