GitHubOrg='GHOrgName'
GitHubUser=$(cat credentials_github_api_username.txt)
GitHubToken=$(cat credentials_github_api_token.txt)
KilnBaseUrl=$(cat kiln_base_url.txt)
KilnApiBaseUrl="$KilnBaseUrl/kiln/Api/1.0"
KilnApiToken=$(cat credentials_kiln_api_token.txt)
BitbucketBaseURL=$(cat bitbucket_base_url.txt)
BitbucketApiBaseURL="$BitbucketBaseURL/rest/api/1.0"
BitbucketUser=$(cat credentials_bitbucket_api_username.txt)
BitbucketPassword=$(cat credentials_bitbucket_api_password.txt)

UseBFG=0
BFG_ExtensionsToLFS=''
BFG_FoldersToDelete=''
BFG_FilesToDelete=''
#
# IF big files should be moved to Git LFS comment out the previous BFG section and uncomment the following one
#
#UseBFG=1
#BFG_ExtensionsToLFS='*.{jpg,bin,png,mp4,gif,swf,jpeg,zip,ico,pdf,flv,xls,psd,jpg_backup,svg,eot,ttf,woff,woff2,bmp,7z,docx,xlsx,apk,exe,sfx,chm,mo,po,pot,3gp,3gpp,ai,app,avi,lzx,gz,otf,swc,rar,rtf,smil,cur,msi,doc,gv,mso,pptx,tgz,vsd,wav,mp3,tar,gz,xar,mdb,gzip,mov,ps,m4v,ppsx,pspimage,vsdx}'
#BFG_FoldersToDelete='{Debug,Releases}'
#BFG_FilesToDelete='{*.class,*.jar}'

MigrationType='kiln_ghc' # OR kiln_bbs
MigrationId='001'
BitbucketProjectName='BBProjectName'
GitHubOrBitbucketTeamName='TeamName'

# Kiln to GitHub
#./migrate_${MigrationType}.sh ./migrations/${MigrationId}_2migrate_${GitHubOrBitbucketTeamName}.txt $GitHubOrg $GitHubUser $GitHubToken $GitHubOrBitbucketTeamName $KilnApiBaseUrl $KilnApiToken $UseBFG $BFG_ExtensionsToLFS $BFG_FoldersToDelete $BFG_FilesToDelete > ./migrate_with_parameters/OUTPUT_mwp_${MigrationId}.txt 2>&1

# Kiln to Bitbucket
#./migrate_${MigrationType}.sh ./migrations/${MigrationId}_2migrate_${GitHubOrBitbucketTeamName}.txt $BitbucketApiBaseURL $BitbucketProjectName $BitbucketUser $BitbucketPassword $BitbucketTeamName $KilnApiBaseUrl $KilnApiToken $UseBFG $BFG_ExtensionsToLFS $BFG_FoldersToDelete $BFG_FilesToDelete > ./migrate_with_parameters/OUTPUT_mwp_${MigrationId}.txt 2>&1
