#!/bin/bash

SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

OldNewReposCsv=$1
GitHubOrg=$2
GitHubUser=$3
GitHubToken=$4
KilnApiBaseUrl=$5
KilnApiToken=$6



printf "\nCreating authors and repos/hg folders\n"
mkdir --parent $SCRIPT_DIR/authors/hg
mkdir --parent $SCRIPT_DIR/repos/hg

printf "\ncurl --insecure --silent \"$KilnApiBaseUrl/Person?token=$KilnApiToken\"\n"
KilnUsers=`curl --insecure --silent "$KilnApiBaseUrl/Person?token=$KilnApiToken"`
printf "KilnUsers | $SCRIPT_DIR/jq '.[] | .sName + \" <\" + .sEmail + \">\"' | sed -e 's/^\"//' -e 's/\"$//'\n"
echo "$KilnUsers" | $SCRIPT_DIR/jq '.[] | .sName + " <" + .sEmail + ">"' | sed -e 's/^"//' -e 's/"$//' > $SCRIPT_DIR/authors/hg/kiln_active_users.txt



OIFS=$IFS
IFS=,
while read OldRepoUrl OldRepoPrjIx OldRepoGrpIx OldRepoIx OldRepoPrjName OldRepoGrpName OldRepoName NewRepoName
do
    printf "\n********************\n"

    printf "\n01. hg clone ${OldRepoUrl} $SCRIPT_DIR/repos/hg/$OldRepoName\n"
    hg clone ${OldRepoUrl} $SCRIPT_DIR/repos/hg/$OldRepoName

    printf "\n02. hg log $SCRIPT_DIR/repos/hg/$OldRepoName --template \"{author}\\n\" > $SCRIPT_DIR/authors/hg/kiln_authors_${OldRepoName}.txt\n"
    hg log $SCRIPT_DIR/repos/hg/$OldRepoName --template "{author}\n" > $SCRIPT_DIR/authors/hg/kiln_authors_${OldRepoName}.txt

    printf "\n03. rm -rf $SCRIPT_DIR/repos/hg/$OldRepoName\n"
    rm -rf $SCRIPT_DIR/repos/hg/$OldRepoName
done < $OldNewReposCsv
IFS=$OIFS



printf "\n@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n"
printf "\n$SCRIPT_DIR/authors/hg/kiln_*.txt | sort | uniq > $SCRIPT_DIR/authors/hg/all_kiln.txt\n"
cat $SCRIPT_DIR/authors/hg/kiln_*.txt | sort | uniq > $SCRIPT_DIR/authors/hg/all_kiln.txt



printf "\n"