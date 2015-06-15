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



if [ ! -d ./fast-export ]; then
    printf "\ngit clone https://github.com/frej/fast-export.git\n"
    git clone https://github.com/frej/fast-export.git $SCRIPT_DIR/fast-export
fi

printf "\nCreating repos/hg and repos/git folders\n"
mkdir --parent $SCRIPT_DIR/repos/hg
mkdir --parent $SCRIPT_DIR/repos/git



OIFS=$IFS
IFS=,
while read OldRepoUrl OldRepoPrjIx OldRepoGrpIx OldRepoIx OldRepoPrjName OldRepoGrpName OldRepoName NewRepoName
do
    printf "\n********************\n"

    printf "\n01. hg clone ${OldRepoUrl} $SCRIPT_DIR/repos/hg/$OldRepoName\n"
    hg clone ${OldRepoUrl} $SCRIPT_DIR/repos/hg/$OldRepoName

    printf "\n02. curl --silent --user \"$GitHubUser:$GitHubToken\" \"https://api.github.com/orgs/$GitHubOrg/repos\" --request POST --data \"{\\\"name\\\": \\\"$NewRepoName\\\", \\\"private\\\": true, \\\"team_id\\\": $GitHubTeamId}\"\n"
    curl --silent --user "$GitHubUser:$GitHubToken" "https://api.github.com/orgs/$GitHubOrg/repos" --request POST --data "{\"name\": \"$NewRepoName\", \"private\": true, \"team_id\": $GitHubTeamId}" > /dev/null

    printf "\n03. git clone \"https://$GitHubUser:$GitHubToken@github.com/$GitHubOrg/${NewRepoName}.git\" $SCRIPT_DIR/repos/git/$NewRepoName\n"
    git clone "https://$GitHubUser:$GitHubToken@github.com/$GitHubOrg/${NewRepoName}.git" $SCRIPT_DIR/repos/git/$NewRepoName

    printf "\n04. cd $SCRIPT_DIR/repos/git/$NewRepoName\n"
    cd $SCRIPT_DIR/repos/git/$NewRepoName

    printf "\n05. $SCRIPT_DIR/fast-export/hg-fast-export.sh -r $SCRIPT_DIR/repos/hg/$OldRepoName\n"
    $SCRIPT_DIR/fast-export/hg-fast-export.sh -r $SCRIPT_DIR/repos/hg/$OldRepoName

    printf "\n06. Checkout and push\n"
    git checkout
    git push --all origin

    printf "\n07. .gitignore\n"
    if [ -f .hgignore ]; then
        printf "    mv .hgignore .gitignore, add, commit and push\n"
        mv .hgignore .gitignore
        git add . --all
        git commit -am'Replace .hgignore with .gitignore'
        git push --all origin
    else
        printf "    Please download and commit the gitignore related to your repo language from http://github.com/github/gitignore\n"
    fi

    printf "\n08. OldRepoNewRepoGroupIx\n"
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

    printf "\n09. curl --insecure --silent \"$KilnApiBaseUrl/Repo/$OldRepoIx\" --request POST --data \"ixRepoGroup=$OldRepoNewRepoGroupIx&token=$KilnApiToken\"\n"
    curl --insecure --silent "$KilnApiBaseUrl/Repo/$OldRepoIx" --request POST --data "ixRepoGroup=$OldRepoNewRepoGroupIx&token=$KilnApiToken" > /dev/null

    printf "\n10. cd ..\n"
    cd ..
done < $OldNewReposCsv
IFS=$OIFS

printf "\n"