# Container image that runs your code
FROM ghcr.io/templateflow/datalad:main

# AWS CLI to delete outdated objects from the S3 export (curl 7.78 cannot sign S3 requests)
RUN python3 -m pip install --no-cache-dir awscli

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
