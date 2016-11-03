#!/bin/bash

SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

GitRepoName=$1
ExtensionsToLFS=$2
FoldersToDelete=$3
FilesToDelete=$4
RemoteOrigin=$5

RepoBackupName=BACKUP_${GitRepoName}
RepoMirrorName=MIRROR_${GitRepoName}



#https://github.com/github/git-lfs/issues/326
#https://github.com/rtyley/bfg-repo-cleaner/releases



if [ ! -f /usr/local/bin/git-lfs ]; then
    printf "\n---------- Installing Git LFS\n"
    mkdir /tmp/gitlfs
    wget https://github.com/github/git-lfs/releases/download/v1.0.2/git-lfs-linux-amd64-1.0.2.tar.gz -O /tmp/gitlfs/gitlfsx64.tar.gz
    tar -zxvf /tmp/gitlfs/gitlfsx64.tar.gz -C /tmp/gitlfs
    for directory in `find /tmp/gitlfs/* -type d`
    do
        mv ${directory} /tmp/gitlfs/git-lfs-install
    done
    sudo mkdir --parent /usr/local/bin
    sudo chown `id -un`:`id -gn` /usr/local/bin
    cd /tmp/gitlfs/git-lfs-install
    ./install.sh
    sudo chown root:root /usr/local/bin
    sudo ln -s /usr/local/bin/git-lfs /usr/local/git/bin/git-lfs
    cd $SCRIPT_DIR
    rm -rf /tmp/gitlfs
fi



if [ ! -f $SCRIPT_DIR/bfg.jar ]; then
    printf "\n---------- Getting BFG repo cleaner\n"
    wget http://repo1.maven.org/maven2/com/madgag/bfg/1.12.14/bfg-1.12.14.jar -O $SCRIPT_DIR/bfg.jar -o /dev/null
fi



printf "\n---------- cd $SCRIPT_DIR/repos/git/\n"
cd $SCRIPT_DIR/repos/git/

printf "\n---------- cp -pr $GitRepoName $RepoBackupName\n"
cp -pr $GitRepoName $RepoBackupName

printf "\n---------- git clone --mirror $GitRepoName $RepoMirrorName\n"
git clone --mirror $GitRepoName $RepoMirrorName

printf "\n---------- Extracting files to lfs/objects and adding .gitattributes for LFS tracking"
printf "\n           java -jar bfg.jar --no-blob-protection --convert-to-git-lfs '$ExtensionsToLFS' --private $RepoMirrorName\n"
java -jar $SCRIPT_DIR/bfg.jar --no-blob-protection --convert-to-git-lfs "$ExtensionsToLFS" --private $RepoMirrorName

printf "\n---------- java -jar bfg.jar --no-blob-protection --delete-folders '$FoldersToDelete' --delete-files '$FilesToDelete' --strip-blobs-bigger-than 99M $RepoMirrorName\n"
#java -jar $SCRIPT_DIR/bfg.jar --no-blob-protection --delete-folders "$FoldersToDelete" --delete-files "$FilesToDelete" --strip-blobs-bigger-than 99M $RepoMirrorName

printf "\n---------- cd $RepoMirrorName\n"
cd $RepoMirrorName

printf "\n---------- git reflog expire --expire=now --all && git gc --prune=now --aggressive\n"
git reflog expire --expire=now --all && git gc --prune=now --aggressive

printf "\n---------- git lfs init\n"
git lfs init

printf "\n---------- git remote set-url origin \"$RemoteOrigin\"\n"
git remote set-url origin "$RemoteOrigin"

printf "\n---------- git push (cloned with --mirror: will push ALL branches and tags)\n"
#git push