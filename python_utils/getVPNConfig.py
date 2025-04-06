import json
from subprocess import PIPE, run
import argparse



def get_dns_inbound_static_ip(file_path):
    with open(file_path, 'r') as json_file:
        data = json.load(json_file)

    return data["parameters"]["dnsResolver"]["value"]["dnsInboundStaticIp"]


def run_pwsh(msg):

    cmd = "powershell -Command" + f''' "{msg}" '''

    return run(
        args=cmd, stdout=PIPE, stderr=PIPE, universal_newlines=True, shell=True
    )



if __name__ == "__main__":
    
    parser = argparse.ArgumentParser(description="Process resource group and VPN name.")
    
    parser.add_argument(
        "--resource_group",
        default= "hub-network-rg",
        required=False,
        help="Name of the resource group"
    )
    
    parser.add_argument(
        "--vpnName",
        default= "p2sVpnGatewayAAD",
        required=False,
        help="Name of the VPN"
    )
    
    args = parser.parse_args()

    rg = args.resource_group
    vpn = args.vpnName


    pwsh_command_lst = [
                    '''mkdir .\.stage; cd .\.stage''',  
                    "Connect-AzAccount",
                     f'''$profile=New-AzVpnClientConfiguration -ResourceGroupName "{rg}" -Name "{vpn}" -AuthenticationMethod "EapTls"''',
                     '''if (Test-Path "p2svpnconfig.zip") {Remove-Item "p2svpnconfig.zip"}''',
                     '''Invoke-WebRequest -uri $PROFILE.VpnProfileSASUrl  -Method "GET"  -Outfile p2svpnconfig.zip''',
                     '''Expand-Archive -Path .\p2svpnconfig.zip -DestinationPath p2svpnconfig''',
                     '''cp .\p2svpnconfig\AzureVPN\\azurevpnconfig.xml ..\\azurevpnconfig.xml''',
                    '''cd ..''',
                    '''Remove-Item -Recurse -Force .stage''',
                     ]
    
    pwsh_command = ";".join(pwsh_command_lst)


    cmd = run_pwsh(pwsh_command)

    inbound_endpoint_ip = get_dns_inbound_static_ip("networkAppliance.parameters.json")

    # for simplicity, just hardcode a replace
    with open('azurevpnconfig.xml','r') as f:
        xml = f.read()
        xml = xml.replace('<clientconfig i:nil="true" />','<clientconfig><dnsservers><dnsserver>10.2.2.4</dnsserver></dnsservers></clientconfig>')
    with open('azurevpnconfig.xml','w') as f:
        f.write(xml)
