#!/bin/bash

SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

OldNewReposCsv=$1
GitHubOrg=$2
GitHubUser=$3
GitHubToken=$4
GitHubTeamName=$5
KilnApiBaseUrl=$6
KilnApiToken=$7



printf "\ncurl --silent --user \"$GitHubUser:$GitHubToken\" \"https://api.github.com/orgs/$GitHubOrg/teams\" | $SCRIPT_DIR/jq \".[] | select(.name==\\\"$GitHubTeamName\\\") | .id\"\n"
GitHubTeamId=`curl --silent --user "$GitHubUser:$GitHubToken" "https://api.github.com/orgs/$GitHubOrg/teams" | $SCRIPT_DIR/jq ".[] | select(.name==\"$GitHubTeamName\") | .id"`
if [ ! $GitHubTeamId ]; then
    printf "Invalid user and/or password\n"
    exit 1
fi



#if [ ! -d $SCRIPT_DIR/fast-export ]; then
#    printf "\ngit clone https://github.com/frej/fast-export.git\n"
#    git clone https://github.com/frej/fast-export.git $SCRIPT_DIR/fast-export
#fi

if [ ! -d $SCRIPT_DIR/fast-export ]; then
    printf "\ngit clone https://github.com/daolis/fast-export.git\n"
    git clone https://github.com/daolis/fast-export $SCRIPT_DIR/fast-export

    printf "\npip install -r requirements-submodules.txt\n"
    pip install -r requirements-submodules.txt
fi

printf "\nCreating repos/hg and repos/git folders\n"
mkdir --parent $SCRIPT_DIR/repos/hg
mkdir --parent $SCRIPT_DIR/repos/git



OIFS=$IFS
IFS=,
while read OldRepoUrl OldRepoPrjIx OldRepoGrpIx OldRepoIx OldRepoPrjName OldRepoGrpName OldRepoName NewRepoName
do
    printf "\n********************\n"

    printf "\n01. hg clone --uncompressed ${OldRepoUrl} $SCRIPT_DIR/repos/hg/$OldRepoName\n"
    hg clone --uncompressed ${OldRepoUrl} $SCRIPT_DIR/repos/hg/$OldRepoName

    printf "\n02. $SCRIPT_DIR/ok.sh org_repos $GitHubOrg _filter='.[] | select(.fork==false) | .name' | grep $NewRepoName | wc -l\n"
    NewRepoNeedsSuffix=$SCRIPT_DIR/ok.sh org_repos $GitHubOrg _filter='.[] | select(.fork==false) | .name | grep $NewRepoName | wc -l'

    printf "\n03. if [ $NewRepoNeedsSuffix -ne 0 ]; then NewRepoSuffix=$(uuidgen -r); NewRepoName=\"${NewRepoName}_${NewRepoSuffix}\"; fi\n"
    if [ $NewRepoNeedsSuffix -ne 0 ]; then NewRepoSuffix=$(uuidgen -r); NewRepoName="${NewRepoName}_${NewRepoSuffix}"; fi

    printf "\n04. curl --silent --user \"$GitHubUser:$GitHubToken\" \"https://api.github.com/orgs/$GitHubOrg/repos\" --request POST --data \"{\\\"name\\\": \\\"$NewRepoName\\\", \\\"private\\\": true, \\\"team_id\\\": $GitHubTeamId}\"\n"
    curl --silent --user "$GitHubUser:$GitHubToken" "https://api.github.com/orgs/$GitHubOrg/repos" --request POST --data "{\"name\": \"$NewRepoName\", \"private\": true, \"team_id\": $GitHubTeamId}" > /dev/null

    printf "\n05. git clone \"https://$GitHubUser:$GitHubToken@github.com/$GitHubOrg/${NewRepoName}.git\" $SCRIPT_DIR/repos/git/$NewRepoName\n"
    git clone "https://$GitHubUser:$GitHubToken@github.com/$GitHubOrg/${NewRepoName}.git" $SCRIPT_DIR/repos/git/$NewRepoName

    printf "\n06. cd $SCRIPT_DIR/repos/git/$NewRepoName\n"
    cd $SCRIPT_DIR/repos/git/$NewRepoName

    printf "\n07. $SCRIPT_DIR/fast-export/hg-fast-export.sh -r $SCRIPT_DIR/repos/hg/$OldRepoName -A $SCRIPT_DIR/authors/authors_mapping.txt\n"
    $SCRIPT_DIR/fast-export/hg-fast-export.sh -r $SCRIPT_DIR/repos/hg/$OldRepoName -A $SCRIPT_DIR/authors/authors_mapping.txt

    if [ -f $SCRIPT_DIR/repos/hg/$OldRepoName/.hgsub ]; then
        printf "\n08. Checkout and submodule init and update\n"
        git checkout
        git submodule init
        git submodule update
    else
        printf "\n08. Checkout\n"
        git checkout
    fi

    printf "\n09. git push --all origin\n"
    git push --all origin

    printf "\n10. .gitignore\n"
    if [ -f .hgignore ]; then
        printf "    mv .hgignore .gitignore, add, commit and push\n"
        mv .hgignore .gitignore
        git add . --all
        git commit -am'Replace .hgignore with .gitignore'
        git push --all origin
    else
        printf "    Please download and commit the gitignore related to your repo language from http://github.com/github/gitignore\n"
    fi

    printf "\n11. OldRepoNewRepoGroupIx\n"
    printf "    curl --insecure --silent \"$KilnApiBaseUrl/Project/$OldRepoPrjIx?token=$KilnApiToken\"\n"
    OldRepoPrjJson=`curl --insecure --silent "$KilnApiBaseUrl/Project/$OldRepoPrjIx?token=$KilnApiToken"`
    printf "    OldRepoPrjJson | $SCRIPT_DIR/jq \".repoGroups[] | select(.sSlug==\\\"${OldRepoGrpName}_MigratedToGitHub\\\") | .ixRepoGroup\"\n"
    OldRepoNewRepoGroupIx=`echo "$OldRepoPrjJson" | $SCRIPT_DIR/jq ".repoGroups[] | select(.sSlug==\"${OldRepoGrpName}_MigratedToGitHub\") | .ixRepoGroup"`
    if [ -z "$OldRepoNewRepoGroupIx" ]; then
        printf "    curl --insecure --silent \"$KilnApiBaseUrl/RepoGroup/Create\" --request POST --data \"ixProject=$OldRepoPrjIx&sName=${OldRepoGrpName}_MigratedToGitHub&token=$KilnApiToken\"\n"
        OldRepoNewRepoGroupData=`curl --insecure --silent "$KilnApiBaseUrl/RepoGroup/Create" --request POST --data "ixProject=$OldRepoPrjIx&sName=${OldRepoGrpName}_MigratedToGitHub&token=$KilnApiToken"`
        printf "    OldRepoNewRepoGroupData | $SCRIPT_DIR/jq '.ixRepoGroup': "
        OldRepoNewRepoGroupIx=`echo "$OldRepoNewRepoGroupData" | $SCRIPT_DIR/jq '.ixRepoGroup'`
        if [ -z "$OldRepoNewRepoGroupIx" ]; then
            printf "invalid\n"
            continue
        else
            printf "$OldRepoNewRepoGroupIx\n"
        fi
    fi

    printf "\n12. curl --insecure --silent \"$KilnApiBaseUrl/Repo/$OldRepoIx\" --request POST --data \"ixRepoGroup=$OldRepoNewRepoGroupIx&token=$KilnApiToken\"\n"
    curl --insecure --silent "$KilnApiBaseUrl/Repo/$OldRepoIx" --request POST --data "ixRepoGroup=$OldRepoNewRepoGroupIx&token=$KilnApiToken" > /dev/null

    printf "\n13. cd ..\n"
    cd ..
done < $OldNewReposCsv
IFS=$OIFS



printf "\n"