/*
 * Copyright (C) 2016 Federico Panini
 * See LICENSE for the copy of MIT license
*/

// BEGIN Lambda configuration
var crypto = require('crypto');
var http = require('http');
var  https = require('https');


var pipelineId = '';

// AWS elastic transcoder presets 
var video_360 = '1455030365353-80u4mw'; //default HLS 360p
var video_480 = '1455033923052-lfe4h2'; // HLS 480p
var video_480p_mp4 = 'custom transcoder preset';

// change these to match your S3 setup
// note: transcoder is picky about characters in the metadata
var region = 'your region';
var targetBucket = 'destination-s3-bucket';
var sourceBucket = 'source-s3-bucket';
var thumbBucket = 'thumbnail-s3-bucket';
var copyright = 'acme.com 2016';

// BEGIN Lambda code
console.log('Loading function');

var aws = require('aws-sdk');
var s3 = new aws.S3();

var eltr = new aws.ElasticTranscoder({
    region: region
});

exports.handler = function(event, context) {
    console.log('Received event:', JSON.stringify(event, null, 2));

    // Get the object from the event and show its content type
    var bucket = event.Records[0].s3.bucket.name;
    var key = event.Records[0].s3.object.key;

    var request = s3.getObject({Bucket: bucket, Key: key});
    
    request.on('error', function(error, response) {
        console.log("Error getting object " + key + " from bucket " + bucket +
            ". Make sure they exist and your bucket is in the same region as this function.");
        console.log(error); console.log(error.stack);
        context.fail('Error', "Error getting file: " + error);
    });
    
    request.on('success', function(response) {
        var data = response.data;
        var manifest = data.Body.toString();
        
        console.log('Received data:', manifest);
        console.log('Received data:', data.ContentLength);
        
        manifest = JSON.parse(manifest);
        sendVideoToET(manifest, context);
    });
    
    request.send();
};

/**
* this function receive the request object informations
* from S3 and try with Elastic Transcoder to 
* encode with a proper format the video uploaded
*/
function sendVideoToET(manifest, context) {
    var key =  manifest.media;
    var user = '';
    if ((manifest.user).length !== 0) {
        user = manifest.user + '/';
    }

    var generate_outputs = function(config) {
        var out = [];
        for (var key in config) {
            var in_ = config[key];
            var out_ = {
                Key: in_.key ? in_.key : in_.preset,
                PresetId: in_.preset,
                Rotate: 'auto',
                Watermarks: [
                    {
                        InputKey: 'logo.png',
                        PresetWatermarkId: 'BottomRight'
                    }
                ]
            };

            if (in_.thumbnail) {
                out_.ThumbnailPattern = 'thumb/thumbnail' + '_{count}';
            }

            if (in_.segmentduration) {
                out_.SegmentDuration = in_.segmentduration;
            }

            out.push(out_);
        }

        return out;
    };
    
    var params = {
        PipelineId: pipelineId,
        OutputKeyPrefix: 'video/' + user + manifest.media + '/',
        Input: {
            Key: key
        },
        Outputs: generate_outputs([
            {
                preset: video_360,
                segmentduration: '60',
            }, {
                preset: video_480,
                thumbnail: true,
                segmentduration: '60',
            }, {
                key: 'video.mp4',
                preset: video_480p_mp4
            }
        ]),
        UserMetadata: {
            date: manifest.date.toString(),
            copyright: copyright
        },
        Playlists: [
            {
                Format: 'HLSv3',
                Name: 'playlist',
                OutputKeys: [
                    video_360,
                    video_480
                ]
            }
        ]
    };
    


    var job = eltr.createJob(params);
    
    job.on('error', function(error, response) {
        console.log('Failed to send new video ' + key + ' to ET');
        console.log(error);
        console.log(error.stack);

        context.fail(error);
    });

    job.on('success', function(response) {
        context.succeed('Completed, job to ET sent succesfully!');
    });
    job.send();
} 
