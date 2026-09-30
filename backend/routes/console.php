<?php

use Illuminate\Support\Facades\Schedule;

Schedule::command('schedule:send-reminders')
    ->everyMinute();