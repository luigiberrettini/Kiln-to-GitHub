GitHubOrg='GHOrgName'
GitHubUser=$(cat credentials_github_api_username.txt)
GitHubToken=$(cat credentials_github_api_token.txt)
KilnBaseUrl=$(cat kiln_base_url.txt)
KilnApiBaseUrl="$KilnBaseUrl/kiln/Api/1.0"
KilnApiToken=$(cat credentials_kiln_api_token.txt)

MigrationId='001'
GitHubTeamName='GHTeamName'
./kiln_filenames_authors_and_subrepos.sh ./migrations/${MigrationId}_2migrate_${GitHubTeamName}.txt $GitHubOrg $GitHubUser $GitHubToken $KilnApiBaseUrl $KilnApiToken
