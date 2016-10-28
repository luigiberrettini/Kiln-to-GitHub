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
mkdir --parent $SCRIPT_DIR/bigfiles/hg
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

    printf "\n03. cd $SCRIPT_DIR/repos/hg/$OldRepoName\n"
    cd $SCRIPT_DIR/repos/hg/$OldRepoName

    # REALLY REALLY SLOW
    printf "\n04. for rev in \`seq 0 \$(hg tip --template '{rev'})\`; do printf \"${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName} - Revision \$rev\\\n\$(hg files -v \"set:size('>5MB')\" -r \$rev)\\\n\\\n\"; done > $SCRIPT_DIR/bigfiles/hg/kiln_bigfiles_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt\n"
    latestRev=`hg tip --template '{rev}'`
    for ((currRev=0; currRev<=$latestRev; currRev++))
    do
        bigFiles=`hg files -v -r $currRev "set:size('>5MB')"`
        if [ ! -z "$bigFiles" ]; then
            printf "${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName} - Revision $currRev\n$bigFiles\n\n"
        fi
    done > $SCRIPT_DIR/bigfiles/hg/kiln_bigfiles_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt

    printf "\n05. cd $SCRIPT_DIR\n"
    cd $SCRIPT_DIR

    printf "\n06. hg log $SCRIPT_DIR/repos/hg/$OldRepoName --template \"{author}\\\\n\" | sort | uniq > $SCRIPT_DIR/authors/hg/kiln_authors_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt\n"
    hg log $SCRIPT_DIR/repos/hg/$OldRepoName --template "{author}\n" | sort | uniq > $SCRIPT_DIR/authors/hg/kiln_authors_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt

    printf "\n07. cp $SCRIPT_DIR/authors/hg/kiln_authors_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt $SCRIPT_DIR/authors/last-migration\n"
    cp $SCRIPT_DIR/authors/hg/kiln_authors_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt $SCRIPT_DIR/authors/last-migration

    printf "\n08. $SCRIPT_DIR/repos/hg/$OldRepoName/.hgsub "
    if [ -f $SCRIPT_DIR/repos/hg/$OldRepoName/.hgsub ]; then
        printf "being copied to $SCRIPT_DIR/subs/hg/kiln_subrepos_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt\n"
        cp $SCRIPT_DIR/repos/hg/$OldRepoName/.hgsub $SCRIPT_DIR/subs/hg/kiln_subrepos_${OldRepoPrjName}_${OldRepoGrpName}_${OldRepoName}.txt
    else
        printf "does not exist\n"
    fi

    printf "\n09. rm -rf $SCRIPT_DIR/repos/hg/$OldRepoName\n"
    rm -rf $SCRIPT_DIR/repos/hg/$OldRepoName
done < $OldNewReposCsv
IFS=$OIFS



printf "\n@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n"
printf "\n$SCRIPT_DIR/filenames/hg/kiln_*.txt | sort | uniq > $SCRIPT_DIR/filenames/hg/all_kiln.txt\n"
cat $SCRIPT_DIR/filenames/hg/kiln_*.txt | sort | uniq > $SCRIPT_DIR/filenames/hg/all_kiln.txt

printf "\n$SCRIPT_DIR/bigfiles/hg/kiln_bigfiles*.txt | sort | uniq > $SCRIPT_DIR/bigfiles/hg/all_kiln.txt\n"
cat $SCRIPT_DIR/bigfiles/hg/kiln_bigfiles*.txt > $SCRIPT_DIR/bigfiles/hg/all_kiln.txt
# TO DO AFTER
# Get-Content .\all_kiln.txt | % { if (-Not [String]::IsNullOrWhiteSpace($_) -And -Not $_.Contains(" - Revision")) { $_ }} | sort | unique > out.txt

printf "\n$SCRIPT_DIR/authors/hg/kiln_*.txt | sort | uniq > $SCRIPT_DIR/authors/hg/all_kiln.txt\n"
cat $SCRIPT_DIR/authors/hg/kiln_*.txt | sort | uniq > $SCRIPT_DIR/authors/hg/all_kiln.txt

printf "\n$SCRIPT_DIR/authors/last-migration/kiln_*.txt | sort | uniq > $SCRIPT_DIR/authors/all_kiln_last-migration.txt\n"
cat $SCRIPT_DIR/authors/last-migration/kiln_*.txt | sort | uniq > $SCRIPT_DIR/authors/all_kiln_last-migration.txt

printf "\nrm -rf $SCRIPT_DIR/authors/last-migration\n"
rm -rf $SCRIPT_DIR/authors/last-migration


printf "\n"