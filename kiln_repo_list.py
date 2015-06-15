import requests
from anvil import Anvil

def main():
    requests.packages.urllib3.disable_warnings()

    in_file = open("./kiln_base_url.txt", "r")
    base_url = in_file.read().replace('\n', '')
    in_file.close()

    anvil = Anvil(base_url, False)
    anvil.create_session_by_prompting()

    repo_indices = set()
    out_file = open("./kiln_repoList.txt", "w")
    for project in anvil.get_projects():
        for repo_group in project.repo_groups:
            for repo in repo_group.repos:
                if not repo.index in repo_indices:
                    repo_indices.add(repo.index)

                    prj_indx = str(project.index)
                    grp_indx = str(repo_group.index)
                    rep_indx = str(repo.index)

                    prj_name = project.name
                    grp_name = repo_group.name
                    rep_name = repo.name

                    prj_slug = repo.project_slug
                    grp_slug = repo.group_slug or 'Group'
                    rep_slug = repo.slug

                    url = base_url + '/Code/' + prj_slug + '/' + grp_slug + '/' + rep_slug
                    indexes = prj_indx + ',' + grp_indx + ',' + rep_indx 
                    names = prj_name + ',' + grp_name + ',' + rep_name
                    out_file.write(url + "," + indexes + "," + names + ',' + rep_name + "\n")
    out_file.close()

if __name__ == '__main__':
    main()
