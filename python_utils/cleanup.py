import logging
from subprocess import PIPE, run
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Union

# Configure logging: console only, no file
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler()]
)

def run_cmd(msg):
    return run(
        args=msg, stdout=PIPE, stderr=PIPE, universal_newlines=True, shell=True
    )

def resource_group_exists(rg_name: str) -> bool:
    cmd = f"az group exists --name {rg_name}"
    result = run_cmd(cmd)
    if result.returncode == 0:
        return result.stdout.strip().lower() == "true"
    else:
        logging.error(f"Failed to check existence of '{rg_name}': {result.stderr.strip()}")
        return False

def delete_resource_group(rg_name: str):
    if resource_group_exists(rg_name):
        logging.info(f"Deleting resource group: {rg_name}")
        result = run_cmd(f"az group delete --name {rg_name} --yes")
        if result.returncode == 0:
            logging.info(f"[SUCCESS] Deleted: {rg_name}")
        else:
            logging.error(f"[ERROR] Failed to delete '{rg_name}': {result.stderr.strip()}")
    else:
        logging.warning(f"[SKIPPED] Resource group '{rg_name}' does not exist.")

def delete_resource_groups(resource_group_list: List[Union[str, List[str]]]):
    for group in resource_group_list:
        rgs = group if isinstance(group, list) else [group]
        logging.info(f"Starting deletion for group: {rgs}")
        
        with ThreadPoolExecutor(max_workers=len(rgs)) as executor:
            futures = {executor.submit(delete_resource_group, rg): rg for rg in rgs}
            for future in as_completed(futures):
                pass  # Logging is handled inside delete_resource_group

if __name__ == "__main__":
    # Replace this list with your actual resource group names, the python code will delete the rg in order and in mutlple thread
    resource_group_list = [
        ["vm", "dbx-data-plane", "dbx-transit"],
        "dbx-network",
        ["hub-network-rg","spoke-network-rg"],
        ["dbx-Private-ManagementRG", "dbx-webauth-ManagementRG"]
    ]
    delete_resource_groups(resource_group_list)

