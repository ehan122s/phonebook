<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Terms of Service (Discord Developer Portal & Web Compliance)
Route::get('/terms', function () {
    return view('legal.terms');
})->name('legal.terms');

Route::get('/terms-of-service', function () {
    return view('legal.terms');
});

// Privacy Policy (Discord Developer Portal & Web Compliance)
Route::get('/privacy', function () {
    return view('legal.privacy');
})->name('legal.privacy');

Route::get('/privacy-policy', function () {
    return view('legal.privacy');
});
