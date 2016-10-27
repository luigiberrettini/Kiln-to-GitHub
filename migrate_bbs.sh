#!/bin/bash

SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

OldNewReposCsv=$1
BitbucketBaseURL=$2
BitbucketProjectName=$3
BitbucketUser=$4
BitbucketPassword=$5
BitbucketTeamName=$6
KilnApiBaseUrl=$7
KilnApiToken=$8
UseBFG=$9
BFG_ExtensionsToLFS=${10}
BFG_FoldersToDelete=${11}
BFG_FilesToDelete=${12}



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



printf "\ncurl --silent --user \"$BitbucketUser:BitbucketPassword\" -H \"X-Atlassian-Token: nocheck\" -H \"Content-Type: application/json\" -X GET \"$BitbucketBaseURL/projects?name=$BitbucketProjectName\" | $SCRIPT_DIR/jq -r '.values | map(select(.name == \"'$BitbucketProjectName'\"))[0].key'\n"
BitbucketProjectKey=`curl --silent --user "$BitbucketUser:$BitbucketPassword" -H "X-Atlassian-Token: nocheck" -H "Content-Type: application/json" -X GET "$BitbucketBaseURL/projects?name=$BitbucketProjectName" | $SCRIPT_DIR/jq -r '.values | map(select(.name == "'$BitbucketProjectName'"))[0].key'`
printf "BitbucketProjectKey: $BitbucketProjectKey"
if [ ! $BitbucketProjectKey ] || [ "$BitbucketProjectKey" == "null" ]; then
    printf "BitbucketProjectKey not found\n"
    exit 1
fi



printf "\ncurl --silent --user \"$BitbucketUser:BitbucketPassword\" -H \"X-Atlassian-Token: nocheck\" -H \"Content-Type: application/json\" -X GET \"$BitbucketBaseURL/groups?filter=$BitbucketTeamName\" | $SCRIPT_DIR/jq '.values | map(select(. == \"'$BitbucketTeamName'\")) | .[]'\n"
TeamPresent=`curl --silent --user "$BitbucketUser:$BitbucketPassword" -H "X-Atlassian-Token: nocheck" -H "Content-Type: application/json" -X GET "$BitbucketBaseURL/groups?filter=$BitbucketTeamName" | $SCRIPT_DIR/jq '.values | map(select(. == "'$BitbucketTeamName'")) | .[]'`
if [ ! $TeamPresent ]; then
    printf "Team does not exist\n"
    exit 1
fi



if [ ! -d $SCRIPT_DIR/fast-export ]; then
    #printf "\ngit clone https://github.com/frej/fast-export.git\n"
    #git clone https://github.com/frej/fast-export.git $SCRIPT_DIR/fast-export

    #printf "\ngit clone https://github.com/daolis/fast-export.git\n"
    #git clone https://github.com/daolis/fast-export $SCRIPT_DIR/fast-export

    printf "\ngit clone https://github.com/luigiberrettini/fast-export.git\n"
    git clone https://github.com/luigiberrettini/fast-export.git $SCRIPT_DIR/fast-export

    printf "\nsudo yum install python-devel\n"
    sudo yum install python-devel

    printf "\nsudo pip install -r /gh_mig/fast-export/requirements-submodules.txt\n"
    sudo pip install -r $SCRIPT_DIR/fast-export/requirements-submodules.txt

    printf "\nsudo pip install -r requirements-submodules.txt\n"
    sudo pip install -r requirements-submodules.txt
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

    printf "\n02. curl --silent --user \"$BitbucketUser:BitbucketPassword\" -H \"X-Atlassian-Token: nocheck\" -H \"Content-Type: application/json\" -X PUT \"$BitbucketBaseURL/repos?projectname=$BitbucketProjectName&name=$NewRepoName\" | $SCRIPT_DIR/jq '.values | map(select(.name == \"'$NewRepoName'\"))[0].slug'\n"
    NewRepoNeedsSuffix=`curl --silent --user "$BitbucketUser:$BitbucketPassword" -H "X-Atlassian-Token: nocheck" -H "Content-Type: application/json" -X PUT "$BitbucketBaseURL/repos?projectname=$BitbucketProjectName&name=$NewRepoName" | $SCRIPT_DIR/jq '.values | map(select(.name == "'$NewRepoName'"))[0].slug'`

    UUID=$(uuidgen -r)
    printf "\n03. if [ $NewRepoNeedsSuffix -ne 0 ]; then NewRepoName=\"${NewRepoName}_${UUID}\"; fi\n"
    if [ $NewRepoNeedsSuffix ] && [ "$NewRepoNeedsSuffix" != "null" ]; then NewRepoName="${NewRepoName}_${UUID}"; fi

    printf "\n04. mkdir $SCRIPT_DIR/repos/git/$NewRepoName\n"
    mkdir $SCRIPT_DIR/repos/git/$NewRepoName

    printf "\n05. cd $SCRIPT_DIR/repos/git/$NewRepoName\n"
    cd $SCRIPT_DIR/repos/git/$NewRepoName

    printf "\n06. git init\n"
    git init

    printf "\n07. $SCRIPT_DIR/fast-export/hg-fast-export.sh -r $SCRIPT_DIR/repos/hg/$OldRepoName -A $SCRIPT_DIR/authors/authors_mapping.txt\n"
    $SCRIPT_DIR/fast-export/hg-fast-export.sh -r $SCRIPT_DIR/repos/hg/$OldRepoName -A $SCRIPT_DIR/authors/authors_mapping.txt --fix-branchnames

    if [ -f $SCRIPT_DIR/repos/hg/$OldRepoName/.hgsub ]; then
        printf "\n08. Checkout and submodule init and update\n"
        git checkout
        git submodule init
        git submodule update
    else
        printf "\n08. Checkout\n"
        git checkout
    fi

    printf "\n09. README.md "
    if [ ! -f README.md ]; then
        printf "created\n"
        printf "# $NewRepoName\n" > README.md
        git add .
        git commit -m 'Add README'
    else
        printf "already present\n"
    fi

    printf "\n10. .gitignore "
    if [ -f .hgignore ]; then
        printf "created from .hgignore\n"
        mv .hgignore .gitignore
        git add . --all
        git commit -m 'Replace .hgignore with .gitignore'
    else
        printf "to be downloaded from http://github.com/github/gitignore\n"
    fi

    printf "\n11. curl --silent --user \"$BitbucketUser:BitbucketPassword\" -H \"X-Atlassian-Token: nocheck\" -H \"Content-Type: application/json\" -X POST -d \"{ \\\"name\\\": \\\"$NewRepoName\\\", \\\"scmId\\\": \\\"git\\\", \\\"forkable\\\": true }\" \"$BitbucketBaseURL/projects/$BitbucketProjectKey/repos\"\n"
    curl --silent --user "$BitbucketUser:$BitbucketPassword" -H "X-Atlassian-Token: nocheck" -H "Content-Type: application/json" -X POST -d "{ \"name\": \"$NewRepoName\", \"scmId\": \"git\", \"forkable\": true }" "$BitbucketBaseURL/projects/$BitbucketProjectKey/repos" > /dev/null

    printf "\n12. curl --silent --user \"$BitbucketUser:BitbucketPassword\" -H \"X-Atlassian-Token: nocheck\" -H \"Content-Type: application/json\" -X PUT \"$BitbucketBaseURL/repos?projectname=$BitbucketProjectName&name=$NewRepoName\" | $SCRIPT_DIR/jq '.values | map(select(.name == \"'$NewRepoName'\"))[0].slug'\n"
    NewRepoSlug=`curl --silent --user "$BitbucketUser:$BitbucketPassword" -H "X-Atlassian-Token: nocheck" -H "Content-Type: application/json" -X PUT "$BitbucketBaseURL/repos?projectname=$BitbucketProjectName&name=$NewRepoName" | $SCRIPT_DIR/jq '.values | map(select(.name == "'$NewRepoName'"))[0].slug'`
    if [ ! $NewRepoSlug ] || [ "$NewRepoSlug" == "null" ]; then
        printf "New repo was not created\n"
        exit 1
    fi

    printf "\n13. curl --silent --user \"$BitbucketUser:BitbucketPassword\" -H \"X-Atlassian-Token: nocheck\" -H \"Content-Type: application/json\" -X PUT \"$BitbucketBaseURL/projects/$BitbucketProjectKey/repos/$NewRepoSlug/permissions/groups?name=$BitbucketTeamName&permission=REPO_ADMIN\"\n"
    curl -H "X-Atlassian-Token: nocheck" -H "Content-Type: application/json" -H "Authorization Basic $authCredentials" -X PUT "$BitbucketBaseURL/projects/$BitbucketProjectKey/repos/$NewRepoSlug/permissions/groups?name=$BitbucketTeamName&permission=REPO_ADMIN" > /dev/null

    RemoteOrigin="$BitbucketBaseURL/scm/$BitbucketProjectKey/${NewRepoName}.git"
    if [ $UseBFG -eq 1 ]; then
        printf "\n14. Migrating binaries to LFS with BFG repo cleaner\n"
        $SCRIPT_DIR/move_large_files_and_apply_ignore.sh $NewRepoName $BFG_ExtensionsToLFS $BFG_FoldersToDelete $BFG_FilesToDelete $RemoteOrigin
    else
        printf "\n14. git remote add origin \"$RemoteOrigin\"\n    git remote -v\n    git push --all origin\n"
        git remote add origin "$RemoteOrigin"
        git remote -v
        git push --all origin
    fi

    printf "\n15. OldRepoNewRepoGroupIx\n"
    printf "    curl --insecure --silent \"$KilnApiBaseUrl/Project/$OldRepoPrjIx?token=$KilnApiToken\"\n"
    OldRepoPrjJson=`curl --insecure --silent "$KilnApiBaseUrl/Project/$OldRepoPrjIx?token=$KilnApiToken"`
    printf "    OldRepoPrjJson | $SCRIPT_DIR/jq \".repoGroups[] | select(.sName==\\\"${OldRepoGrpName}_MigratedToBitbucket\\\") | .ixRepoGroup\"\n"
    OldRepoNewRepoGroupIx=`echo "$OldRepoPrjJson" | $SCRIPT_DIR/jq ".repoGroups[] | select(.sName==\"${OldRepoGrpName}_MigratedToBitbucket\") | .ixRepoGroup"`
    if [ -z "$OldRepoNewRepoGroupIx" ]; then
        printf "    curl --insecure --silent \"$KilnApiBaseUrl/RepoGroup/Create\" --request POST --data \"ixProject=$OldRepoPrjIx&sName=${OldRepoGrpName}_MigratedToBitbucket&token=$KilnApiToken\"\n"
        OldRepoNewRepoGroupData=`curl --insecure --silent "$KilnApiBaseUrl/RepoGroup/Create" --request POST --data "ixProject=$OldRepoPrjIx&sName=${OldRepoGrpName}_MigratedToBitbucket&token=$KilnApiToken"`
        printf "    OldRepoNewRepoGroupData | $SCRIPT_DIR/jq '.ixRepoGroup': "
        OldRepoNewRepoGroupIx=`echo "$OldRepoNewRepoGroupData" | $SCRIPT_DIR/jq '.ixRepoGroup'`
        if [ -z "$OldRepoNewRepoGroupIx" ]; then
            printf "invalid\n"
            continue
        else
            printf "$OldRepoNewRepoGroupIx\n"
        fi
    fi

    printf "\n16. curl --insecure --silent \"$KilnApiBaseUrl/Repo/$OldRepoIx\" --request POST --data \"ixRepoGroup=$OldRepoNewRepoGroupIx&token=$KilnApiToken\"\n"
    curl --insecure --silent "$KilnApiBaseUrl/Repo/$OldRepoIx" --request POST --data "ixRepoGroup=$OldRepoNewRepoGroupIx&token=$KilnApiToken" > /dev/null

    printf "\n17. cd $SCRIPT_DIR\n"
    cd $SCRIPT_DIR
done < $OldNewReposCsv
IFS=$OIFS



printf "\n"