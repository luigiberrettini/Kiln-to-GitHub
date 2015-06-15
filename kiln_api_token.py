import requests
from anvil import Anvil

def main():
    requests.packages.urllib3.disable_warnings()

    in_file = open("./kiln_base_url.txt", "r")
    base_url = in_file.read().replace('\n', '')
    in_file.close()

    anvil = Anvil(base_url, False)
    anvil.create_session_by_prompting()
    
    out_file = open("./credentials_kiln_api_token.txt", "w")
    out_file.write(str(anvil.token))
    out_file.close()

if __name__ == '__main__':
    main()
