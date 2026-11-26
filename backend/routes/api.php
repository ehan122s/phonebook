<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\ReportPhotoController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\MaterialController;
use App\Http\Controllers\Api\ScheduleController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\BugReportController;
use App\Http\Controllers\Api\DiscordInteractionController;
use App\Http\Controllers\Api\ReportTemplateController;
use App\Http\Controllers\Api\AppUpdateController;

Route::get('/test', function () {
    return response()->json([
        'success' => true,
        'message' => 'API Phonebook berhasil terhubung',
    ]);
});

/*
|--------------------------------------------------------------------------
| Report Templates (Supabase PostgreSQL Form Configuration & Fields)
|--------------------------------------------------------------------------
*/

Route::get('/report-templates', [ReportTemplateController::class, 'index']);
Route::get('/report-templates/{id}', [ReportTemplateController::class, 'show']);
Route::post('/report-templates', [ReportTemplateController::class, 'store']);
Route::put('/report-templates/{id}', [ReportTemplateController::class, 'update']);
Route::post('/report-templates/{id}', [ReportTemplateController::class, 'update']);
Route::delete('/report-templates/{id}', [ReportTemplateController::class, 'destroy']);

/*
|--------------------------------------------------------------------------
| Reports
|--------------------------------------------------------------------------
*/

Route::middleware('auth:sanctum')->group(function () {

    Route::get('/reports', [ReportController::class, 'index']);
    Route::post('/reports', [ReportController::class, 'store']);
    Route::get('/reports/{id}', [ReportController::class, 'show']);
    Route::put('/reports/{id}', [ReportController::class, 'update']);
    Route::delete('/reports/{id}', [ReportController::class, 'destroy']);

    Route::post('/reports/{reportId}/photos', [ReportPhotoController::class, 'store']);
    Route::delete('/report-photos/{id}', [ReportPhotoController::class, 'destroy']);
});

// Endpoint publik penyajian berkas foto lampiran laporan (untuk preview Flutter Image.network / browser)
Route::get('/report-photos/{id}/file', [ReportPhotoController::class, 'file']);
Route::get('/reports/{reportId}/photos/{photoId}/file', [ReportPhotoController::class, 'file']);


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
| Materials (Materi Edukasi - Terlihat oleh Semua User)
|--------------------------------------------------------------------------
*/

Route::get('/materials', [MaterialController::class, 'index']);
Route::get('/materials/{id}', [MaterialController::class, 'show']);
Route::get('/materials/{id}/download', [MaterialController::class, 'download']);
Route::post('/materials/public', [MaterialController::class, 'store']);
Route::post('/materials/{id}/public', [MaterialController::class, 'update']);
Route::put('/materials/{id}/public', [MaterialController::class, 'update']);
Route::delete('/materials/{id}/public', [MaterialController::class, 'destroy']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/materials', [MaterialController::class, 'store']);
    Route::post('/materials/{id}', [MaterialController::class, 'update']);
    Route::put('/materials/{id}', [MaterialController::class, 'update']);
    Route::delete('/materials/{id}', [MaterialController::class, 'destroy']);
});

/*
|--------------------------------------------------------------------------
| Schedules & WhatsApp Reminders
|--------------------------------------------------------------------------
*/

Route::post('/whatsapp/send-reminder', [ScheduleController::class, 'directSend']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/schedules', [ScheduleController::class, 'index']);
    Route::get('/schedules/{id}', [ScheduleController::class, 'show']);
    Route::post('/schedules', [ScheduleController::class, 'store']);
    Route::put('/schedules/{id}', [ScheduleController::class, 'update']);
    Route::patch('/schedules/{id}', [ScheduleController::class, 'update']);
    Route::delete('/schedules/{id}', [ScheduleController::class, 'destroy']);
    Route::post('/schedules/{id}/send-whatsapp', [ScheduleController::class, 'sendWhatsapp']);
});

/*
|--------------------------------------------------------------------------
| Notifications (Pengelolaan Notifikasi Pengguna)
|--------------------------------------------------------------------------
*/

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::post('/notifications', [NotificationController::class, 'store']);
    Route::patch('/notifications/read-all', [NotificationController::class, 'markAllAsRead']);
    Route::patch('/notifications/{id}/read', [NotificationController::class, 'markAsRead']);
    Route::delete('/notifications/clear-all', [NotificationController::class, 'destroyAll']);
    Route::delete('/notifications', [NotificationController::class, 'destroyAll']);
    Route::delete('/notifications/{id}', [NotificationController::class, 'destroy']);
});

/*
|--------------------------------------------------------------------------
| Bug Reports / Laporan Masalah (Sistem Tiket & Discord Approval)
|--------------------------------------------------------------------------
*/

Route::middleware(['throttle:30,1'])->group(function () {
    Route::post('/bug-reports', [BugReportController::class, 'store']);
    Route::get('/bug-reports', [BugReportController::class, 'index']);
    Route::get('/bug-reports/{id}', [BugReportController::class, 'show']);
    Route::post('/bug-reports/{id}/retry-discord', [BugReportController::class, 'retryDiscord']);
    Route::match(['GET', 'POST'], '/bug-reports/{id}/action', [DiscordInteractionController::class, 'triggerAction']);
    Route::match(['GET', 'POST'], '/tickets/{ticketCode}/action', [DiscordInteractionController::class, 'triggerAction']);
    Route::post('/discord/interactions', [DiscordInteractionController::class, 'handle']);
});

/*
|--------------------------------------------------------------------------
| App Updates (Sistem Pembaruan Aplikasi Phonebook)
|--------------------------------------------------------------------------
*/
Route::get('/app-update/latest', [AppUpdateController::class, 'latest']);
Route::get('/app-update/check', [AppUpdateController::class, 'check']);
Route::post('/app-update/check', [AppUpdateController::class, 'check']);
Route::get('/app-update/history', [AppUpdateController::class, 'history']);
Route::post('/app-update', [AppUpdateController::class, 'store']);
Route::post('/app-update/{id}/publish', [AppUpdateController::class, 'publish']);
Route::post('/app-update/{id}/unpublish', [AppUpdateController::class, 'unpublish']);
Route::delete('/app-update/{id}', [AppUpdateController::class, 'destroy']);
Route::post('/discord/send-update-panel', function () {
    $res = \App\Services\DiscordAppUpdateService::sendControlPanelToChannel();
    return response()->json($res, $res['success'] ? 200 : 500);
});

/*
|--------------------------------------------------------------------------
| Users (Manajemen Pengguna - Database User)
|--------------------------------------------------------------------------
*/
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/users', [UserController::class, 'index']);
    Route::post('/users', [UserController::class, 'store']);
    Route::put('/users/{id}', [UserController::class, 'update']);
    Route::delete('/users/{id}', [UserController::class, 'destroy']);
    Route::get('/admin/monitoring', [UserController::class, 'monitoring']);
});

/*
|--------------------------------------------------------------------------
| Authentication
|--------------------------------------------------------------------------
*/

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/auth/google', [AuthController::class, 'googleAuth']);
Route::post('/google-check', [AuthController::class, 'googleCheck']);
Route::post('/google-register', [AuthController::class, 'googleRegister']);
Route::post('/google-login', [AuthController::class, 'googleLogin']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', [AuthController::class, 'user']);
    Route::post('/user/profile', [AuthController::class, 'updateProfile']);
    Route::post('/user/change-password', [AuthController::class, 'changePassword']);
    Route::post('/logout', [AuthController::class, 'logout']);
});