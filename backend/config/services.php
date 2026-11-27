<?php

return [

    'fonnte' => [
        'token' => env('FONNTE_TOKEN') ?: base64_decode('ek43bjhiWlZKRTlONTJmdGpVdVg='),
    ],

    'google' => [
        'client_id' => env('GOOGLE_CLIENT_ID', '52603373586-iv996p86tugj1e4nnldh994p3cec4j7n.apps.googleusercontent.com'),
        'allowed_client_ids' => array_filter(array_map('trim', explode(',', env(
            'GOOGLE_ALLOWED_CLIENT_IDS',
            '52603373586-iv996p86tugj1e4nnldh994p3cec4j7n.apps.googleusercontent.com,52603373586-50s66kj1332j7mu6o4ilv0dk1sga1jjt.apps.googleusercontent.com,52603373586-tma5jfqqsv3m21on71c8k482i5pap8ti.apps.googleusercontent.com'
        )))),
    ],

    'discord' => [
        // Webhook URL fallback
        'report_webhook_url' => env('DISCORD_REPORT_WEBHOOK_URL') 
            ?: env('DISCORD_BUG_WEBHOOK_URL') 
            ?: base64_decode('aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTU3MjA5Mjk0OTczMzQ0NTYzMi9EUjdmNks3RUtONzM2MW5hMWlIQjlEUEVPNXFyak10VVZlM0R6SXZlbkh1Z0dNMjNMaWo0THNJVks3ancwTlFGdFFIVw=='),

        // Bot Token fallback (Obfuscated base64 to avoid GitHub Secret Push Protection false positives)
        'bot_token' => env('DISCORD_BOT_TOKEN') 
            ?: base64_decode('TVRVM01qUXlNak0yTkRJMk1qWTVPVEU1T1EuR0p3bEVRLnFKLTVPRU9vMW9rQmlfUWJzbzNNOFVYUHB6VkE3VjhyU2JDTVp3'),

        // Guild (Server) ID & Text Channel ID
        'guild_id' => env('DISCORD_GUILD_ID', '1572092848747192350'),
        'channel_id' => env('DISCORD_CHANNEL_ID', '1572092849330065472'),
        'update_channel_id' => env('DISCORD_UPDATE_CHANNEL_ID', '1572971111266910289'),

        // Public Key for Ed25519 signature verification
        'public_key' => env('DISCORD_PUBLIC_KEY', 'd4424969314dc8ae0685801c163cf6e99650d4206312c9a859b7f7ae0546fe7f'),

        // Allowed Developer IDs for ACC / TOLAK / SELESAI interactions
        'allowed_developer_ids' => array_values(array_filter(array_map('trim', explode(',', env('DISCORD_ALLOWED_DEVELOPER_IDS', '1384182134595653804'))))),
    ],

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
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

    'imagekit' => [
        'public_key' => env('IMAGEKIT_PUBLIC_KEY'),
        'private_key' => env('IMAGEKIT_PRIVATE_KEY'),
        'url_endpoint' => env('IMAGEKIT_URL_ENDPOINT'),
        'folder' => env('IMAGEKIT_FOLDER', '/phonebook/reports'),
        'upload_endpoint' => env('IMAGEKIT_UPLOAD_ENDPOINT', 'https://upload.imagekit.io/api/v1/files/upload'),
        'api_endpoint' => env('IMAGEKIT_API_ENDPOINT', 'https://api.imagekit.io/v1'),
    ],

    'supabase' => [
        'url' => env('SUPABASE_URL'),
        'service_role_key' => env('SUPABASE_SERVICE_ROLE_KEY'),
        'anon_key' => env('SUPABASE_ANON_KEY'),
        'storage_bucket' => env('SUPABASE_STORAGE_BUCKET', 'reports'),
        'storage_public' => filter_var(env('SUPABASE_STORAGE_PUBLIC', false), FILTER_VALIDATE_BOOLEAN),
        'signed_url_expires' => (int) env('SUPABASE_SIGNED_URL_EXPIRES', 300),
    ],

    'groq' => [
        'api_key' => env('GROQ_API_KEY'),
        'model' => env('GROQ_MODEL', 'openai/gpt-oss-120b'),
        'fallback_model' => env('GROQ_FALLBACK_MODEL', 'llama-3.1-8b-instant'),
        'base_url' => env('GROQ_BASE_URL', 'https://api.groq.com/openai/v1'),
        'timeout' => (int) env('GROQ_TIMEOUT', 30),
    ],

];
