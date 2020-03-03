# ------------------------- Synapse endpoints ----------------------------------
# Synapse REST API docs:
# https://rest-docs.synapse.org/rest/index.html

# Note: we're using the Python client because the R synapse client is incompatible 
# with reticulate and it uses PythonEmbedInR, which has issues on shinyapps.io

import synapseclient
import requests
import json

syn = synapseclient.Synapse()

def login_to_synapse(username, api_key):
  syn.login(email=username, apiKey=api_key, rememberMe=True)
  
def get_synapse_userinfo(access_token):
  
  endpoint = "https://repo-prod.prod.sagebase.org/auth/v1/oauth2/userinfo"
  headers = {"Authorization": "Bearer " + access_token}
  
  response = requests.get(endpoint, headers=headers).json()
  return(response)
  
def get_synapse_user_profile():
  
  response = syn.getUserProfile()
  return(response)
  
def get_synapse_teams(user_id):
  
  endpoint = "https://repo-prod.prod.sagebase.org/repo/v1/user/" + user_id + "/team"
  response = requests.get(endpoint).json()
  return(response)
  
def get_synapse_projects(access_token):
  
  endpoint = "https://repo-prod.prod.sagebase.org/repo/v1/projects/"
  headers = {"Authorization": "Bearer " + access_token}
  response = requests.get(endpoint).json()
  return(response)
  
def fetch_synapse_filepath(entity_id):
  entity = syn.get(entity_id, downloadLocation='data', ifcollision='overwrite.local')
  return(entity.path)
  
def create_prod_client():
  
  client_meta_data = {
    'client_name': '<YOUR NAME HERE>',
    'redirect_uris': [
      '<YOUR URI HERE>'
    ],
    'client_uri': '<YOUR URI HERE>'
  }
  
  # Create the client:
  client_meta_data = syn.restPOST(uri='/oauth2/client', 
  	endpoint=syn.authEndpoint, body=json.dumps(client_meta_data))
  
  client_id = client_meta_data['client_id']

  # Generate and retrieve the client secret:
  client_id_and_secret = syn.restPOST(uri='/oauth2/client/secret/'+client_id, 
    endpoint=syn.authEndpoint, body='')
  return(client_id_and_secret)
  
def create_local_client():
  
  client_meta_data = {
    'client_name': '<YOUR LOCAL NAME HERE>',
    'redirect_uris': [
      'http://127.0.0.1:7450'
    ]
  }
  
  # Create the client:
  client_meta_data = syn.restPOST(uri='/oauth2/client', 
  	endpoint=syn.authEndpoint, body=json.dumps(client_meta_data))
  
  client_id = client_meta_data['client_id']

  # Generate and retrieve the client secret:
  client_id_and_secret = syn.restPOST(uri='/oauth2/client/secret/'+client_id, 
    endpoint=syn.authEndpoint, body='')
  return(client_id_and_secret)

 
""" 
# To change client meta-data

# Retrieve a client using its ID:
client_meta_data = syn.restGET(uri='/oauth2/client/'+client_id, 
	endpoint=syn.authEndpoint)
	
# Alter the desired field
client_meta_data['client_name'] = 'Predictive BioAnalytics at Wyss Institute'
client_meta_data.pop('userinfo_signed_response_alg')

# Update a client's metadata:
client_meta_data = syn.restPUT(uri='/oauth2/client/'+client_id, 
	endpoint=syn.authEndpoint, body=json.dumps(client_meta_data))
"""
