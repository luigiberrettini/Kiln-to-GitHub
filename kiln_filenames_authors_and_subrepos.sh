#!/bin/bash

SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

OldNewReposCsv=$1
GitHubOrg=$2
GitHubUser=$3
GitHubToken=$4
KilnApiBaseUrl=$5
KilnApiToken=$6



printf "\nLine endings: "
CarriageReturns=`grep -r $'\r' $OldNewReposCsv | wc -l`
if [ $CarriageReturns -gt 0 ]; then
    echo 'Windows (FATAL ERROR)'
    exit 1
else
    echo 'Unix (OK)'
fi



printf "\nFix trailing new line\n"
tail -c1 $OldNewReposCsv | read -r _ || echo >> $OldNewReposCsv



printf "\nCreating authors and repos/hg folders\n"
mkdir --parent $SCRIPT_DIR/repos/hg
mkdir --parent $SCRIPT_DIR/filenames/hg
mkdir --parent $SCRIPT_DIR/authors/hg
mkdir --parent $SCRIPT_DIR/authors/last-migration
mkdir --parent $SCRIPT_DIR/subs/hg



printf "\ncurl --insecure --silent \"$KilnApiBaseUrl/Person?token=$KilnApiToken\"\n"
KilnUsers=`curl --insecure --silent "$KilnApiBaseUrl/Person?token=$KilnApiToken"`
printf "KilnUsers | $SCRIPT_DIR/jq '.[] | .sName + \" <\" + .sEmail + \">\"' | sed -e 's/^\"//' -e 's/\"$//' | sort | uniq\n"
echo "$KilnUsers" | $SCRIPT_DIR/jq '.[] | .sName + " <" + .sEmail + ">"' | sed -e 's/^"//' -e 's/"$//' | sort | uniq > $SCRIPT_DIR/authors/hg/kiln_active_users.txt



OIFS=$IFS
IFS=,
while read OldRepoUrl OldRepoPrjIx OldRepoGrpIx OldRepoIx OldRepoPrjName OldRepoGrpName OldRepoName NewRepoName
do
    printf "\n********************\n"

    printf "\n01. hg clone --uncompressed ${OldRepoUrl} $SCRIPT_DIR/repos/hg/$OldRepoName\n"
    hg clone --uncompressed ${OldRepoUrl} $SCRIPT_DIR/repos/hg/$OldRepoName

    printf "\n02. hg log $SCRIPT_DIR/repos/hg/$OldRepoName --style $SCRIPT_DIR/kiln_filenames_hg_log_style | sort | uniq > $SCRIPT_DIR/filenames/hg/kiln_filenames_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt\n"
    hg log $SCRIPT_DIR/repos/hg/$OldRepoName --style $SCRIPT_DIR/kiln_filenames_hg_log_style | sort | uniq > $SCRIPT_DIR/filenames/hg/kiln_filenames_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt
    
    printf "\n03. hg log $SCRIPT_DIR/repos/hg/$OldRepoName --template \"{author}\\\\n\" | sort | uniq > $SCRIPT_DIR/authors/hg/kiln_authors_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt\n"
    hg log $SCRIPT_DIR/repos/hg/$OldRepoName --template "{author}\n" | sort | uniq > $SCRIPT_DIR/authors/hg/kiln_authors_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt

    printf "\n04. cp $SCRIPT_DIR/authors/hg/kiln_authors_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt $SCRIPT_DIR/authors/last-migration\n"
    cp $SCRIPT_DIR/authors/hg/kiln_authors_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt $SCRIPT_DIR/authors/last-migration

    printf "\n05. $SCRIPT_DIR/repos/hg/$OldRepoName/.hgsub "
    if [ -f $SCRIPT_DIR/repos/hg/$OldRepoName/.hgsub ]; then
        printf "being copied to $SCRIPT_DIR/subs/hg/kiln_subrepos_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt\n"
        cp $SCRIPT_DIR/repos/hg/$OldRepoName/.hgsub $SCRIPT_DIR/subs/hg/kiln_subrepos_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt
    else
        printf "does not exist\n"
    fi

    printf "\n06. rm -rf $SCRIPT_DIR/repos/hg/$OldRepoName\n"
    rm -rf $SCRIPT_DIR/repos/hg/$OldRepoName
done < $OldNewReposCsv
IFS=$OIFS



printf "\n@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n"
printf "\n$SCRIPT_DIR/filenames/hg/kiln_*.txt | sort | uniq > $SCRIPT_DIR/filenames/hg/all_kiln.txt\n"
cat $SCRIPT_DIR/filenames/hg/kiln_*.txt | sort | uniq > $SCRIPT_DIR/filenames/hg/all_kiln.txt

printf "\n$SCRIPT_DIR/authors/hg/kiln_*.txt | sort | uniq > $SCRIPT_DIR/authors/hg/all_kiln.txt\n"
cat $SCRIPT_DIR/authors/hg/kiln_*.txt | sort | uniq > $SCRIPT_DIR/authors/hg/all_kiln.txt

printf "\n$SCRIPT_DIR/authors/last-migration/kiln_*.txt | sort | uniq > $SCRIPT_DIR/authors/all_last-migration.txt\n"
cat $SCRIPT_DIR/authors/last-migration/kiln_*.txt | sort | uniq > $SCRIPT_DIR/authors/all_last-migration.txt

printf "\nrm -rf $SCRIPT_DIR/authors/last-migration\n"
rm -rf $SCRIPT_DIR/authors/last-migration


printf "\n"