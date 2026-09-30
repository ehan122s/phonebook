<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\MaterialController;
use App\Http\Controllers\Api\ScheduleController;

Route::get('/test', function () {
    return response()->json([
        'success' => true,
        'message' => 'API Phonebook berhasil terhubung',
    ]);
});

/*
|--------------------------------------------------------------------------
| Reports
|--------------------------------------------------------------------------
*/

Route::get('/reports', [ReportController::class, 'index']);
Route::get('/reports/{id}', [ReportController::class, 'show']);
Route::post('/reports', [ReportController::class, 'store']);

/*
|--------------------------------------------------------------------------
| Categories
|--------------------------------------------------------------------------
*/

Route::get('/categories', [CategoryController::class, 'index']);
Route::get('/categories/{id}', [CategoryController::class, 'show']);
Route::post('/categories', [CategoryController::class, 'store']);
Route::put('/categories/{id}', [CategoryController::class, 'update']);
Route::delete('/categories/{id}', [CategoryController::class, 'destroy']);

/*
|--------------------------------------------------------------------------
| Materials
|--------------------------------------------------------------------------
*/

Route::get('/materials', [MaterialController::class, 'index']);
Route::get('/materials/{id}', [MaterialController::class, 'show']);
Route::post('/materials', [MaterialController::class, 'store']);
Route::post('/materials/{id}', [MaterialController::class, 'update']);
Route::delete('/materials/{id}', [MaterialController::class, 'destroy']);

/*
|--------------------------------------------------------------------------
| Schedules
|--------------------------------------------------------------------------
*/

Route::get('/schedules', [ScheduleController::class, 'index']);
Route::get('/schedules/{id}', [ScheduleController::class, 'show']);
Route::post('/schedules', [ScheduleController::class, 'store']);
Route::put('/schedules/{id}', [ScheduleController::class, 'update']);
Route::delete('/schedules/{id}', [ScheduleController::class, 'destroy']);