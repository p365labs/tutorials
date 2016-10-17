#!/bin/bash

#*******************************************************************
#
# this script is an example of restore script.
# I'm using a similar script for restoring the the cluster on 
# development. You can tweak it freely ;)
#
##*******************************************************************

function start_elasticsearch {
    echo "start Elasticsearch"
    elastic_start_echo=$(sudo service elasticsearch start)
    if [[ $elastic_start_echo =~ "done" ]]
    then
        echo "Elasticsearch Restarted! wait a bit until the service comes up!"
        sleep 10;
    else
        echo "Elasticsearch didn't Restarted! exiting"
        exit 126
    fi
}

function stop_elasticsearch {
    echo "stop Elasticsearch..."
    elastic=$(sudo service elasticsearch stop)
    if [[ $elastic =~ "done" ]]
    then
        echo "Elasticsearch stopped."
    else
        echo "Elasticsearch didn't stopped. exiting script..."
        echo
        exit 126
    fi
}

function check_es_plugin {
    echo "check Elasticsearch plugin... $1"
    regex=$1
    f=$(sudo /usr/share/elasticsearch/bin/plugin list |grep cloud-aws)
    if [[ $f =~ $regex ]]
    then
        echo "Elasticsearch cloud-aws installed..."
    else
        stop_elasticsearch

        warn "Elasticsearch cloud-aws not installed..."
        echo "installing..."
        installation_aws_plugin=$(sudo /usr/share/elasticsearch/bin/plugin install -b cloud-aws)
    fi
}

function create_es_repository {
    echo "create snapshot repository : $1"
    repository_name=$1
    hostname=${2:-localhost}

    echo
    echo "Ensure repository is correctly setup"
    repo=$(curl -s -XPUT http://$hostname:9200/_snapshot/$1 -d'
    {
      "type": "s3",
      "settings": {
        "bucket": "s3_repository_bucket",
        "region": "eu-west-1",
        "access_key": "YOUR_AWS_KEY",
        "secret_key": "YOUR_SECRET_KEY"
      }
    }')

    if [[ $repo =~ "true" ]]
    then
        echo "repository created."
    else
        warn "repository 's3_repository' not created."
    fi
}

function es_status {
    echo
    echo "Now you have to wait a couple of minutes ES will rebuild indices."
    echo "Use curl http://localhost:9200/_cat/health?v to check when Restore end."
    echo "Paramenter active_shard_percent == 50 means the process finished."
    sleep 4s;

    echo
    curl --url "http://localhost:9200/_cat/health?v"
    echo
    echo
    sleep 5s;
}
DIRECTORY=/vagrant/web
if [ -d "$DIRECTORY" ]; then

    echo "************************************************************+"
    echo "Elasticsearch - Backup is scheduled on production at 2:30AM +"
    echo "************************************************************+"

    check_es_plugin "cloud-aws"

    start_elasticsearch

    create_es_repository "s3_repository"

    now=$(date +"%Y%m%d")

    echo
    echo "remove elasticsearch indices"
    curl -s -XDELETE --url "http://localhost:9200/*" > /dev/null

    echo "restore elasticsearch indices"
    curl -s -XPOST --url "http://localhost:9200/_snapshot/s3_repository/snap1/_restore" -d'
    {
        "rename_pattern": "(\\w+)",
        "rename_replacement": "$1_dev"
    }' > /dev/null

    es_status
else
    echo "You are allowed to execute this command ONLY in DEV Environment !!! \n"
fi
