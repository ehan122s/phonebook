<?php

return [
	'fonnte' => [
    'token' => env('FONNTE_TOKEN'),
],

    'google' => [
        'client_id' => env('GOOGLE_CLIENT_ID', '52603373586-iv996p86tugj1e4nnldh994p3cec4j7n.apps.googleusercontent.com'),
        'allowed_client_ids' => array_filter(array_map('trim', explode(',', env(
            'GOOGLE_ALLOWED_CLIENT_IDS',
            '52603373586-iv996p86tugj1e4nnldh994p3cec4j7n.apps.googleusercontent.com,52603373586-50s66kj1332j7mu6o4ilv0dk1sga1jjt.apps.googleusercontent.com,52603373586-tma5jfqqsv3m21on71c8k482i5pap8ti.apps.googleusercontent.com'
        )))),
    ],



    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

];
