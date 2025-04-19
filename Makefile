.PHONY: clean deploy_network deploy_dx

clean:
	python python_utils/cleanup.py

deploy_network:
	az deployment sub create --template-file networkAppliance.bicep --parameters networkAppliance.parameters.json --location eastus

deploy_dx:
	az deployment sub create --template-file main.bicep --parameters main.parameters.json --location eastus