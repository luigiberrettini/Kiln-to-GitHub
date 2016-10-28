SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

GitHubUser=$(cat $SCRIPT_DIR/credentials_github_api_username.txt)
GitHubToken=$(cat $SCRIPT_DIR/credentials_github_api_token.txt)

echo 'machine api.github.com' > ~/.netrc
echo "    login $GitHubUser" >> ~/.netrc
echo "    password $GitHubToken" >> ~/.netrc

export OK_SH_URL=https://api.github.com
export OK_SH_ACCEPT=application/vnd.github.v3+json
export OK_SH_JQ_BIN="$SCRIPT_DIR/jq"

