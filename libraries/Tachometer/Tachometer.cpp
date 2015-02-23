#include <Tachometer.h>
#include <Arduino.h>

Tachometer::Tachometer(int pin_assignment, int ppr, int speed){
    pulses_per_revolution = ppr;
    tach_speed = speed;
    pinMode(pin_assignment, INPUT_PULLUP);
    trigger_counts = 0;
    //trigger_count_accumulator[] = {0,0,0,0,0,0,0,0,0,0};
}

void Tachometer::interrupt_function(){

    trigger_time = micros();
    trigger_counts++;
}    

float Tachometer::calc_rpm_slow(){
    return (rpm_measured_slow + (60000000.0/(float)trigger_timing)/pulses_per_revolution)/2 ;        //Simple Low-pass Filter
}

float Tachometer::calc_rpm_fast(){
    int pulse_total = 0;
    for (int i = 0; i < 10; i++){
        pulse_total += trigger_count_accumulator[i];
    }
    return pulse_total*600/pulses_per_revolution;
}

void Tachometer::timer_overflow_handler(){
    //we will throw out whatever data we have
    trigger_time_old = 0;
    trigger_time = 0;

    //and the next capture too
    timing_overflow_trigger_skip == true;
}

void Tachometer::check_pulses(unsigned long fl_timer){

    if (tach_speed == TACH_HIGH_SPEED){
        return;
    }

    if ( (trigger_time_old + (3 * trigger_timing)) < fl_timer ){        // We have lost more than 1 expected pulse, start to decay the measured RPM
        rpm_measured_slow *= 0.99;
        if (rpm_measured_slow < 0){
            rpm_measured_slow = 0;
        }
    }

    if (trigger_time_old != trigger_time){                              // We have new trigger_1_timing data to consume
        if (!timing_overflow_trigger_skip){                             // If micros has not overflowed, we will calculate trigger_1_timing based on this data
            trigger_timing_old = trigger_timing;
            trigger_timing = trigger_time - trigger_time_old;
            rpm_measured_slow = calc_rpm_slow();
        } else {
            timing_overflow_trigger_skip = false;                       // If micros has overflowed, reset the skip bit since we have thrown away this bad data
        }
        trigger_time_old = trigger_time;                                // In either case, we need to do this so we can look for new data
    }
}

void Tachometer::count_pulses(){

    for (int i = 9; i > 0; i--){
        trigger_count_accumulator[i] = trigger_count_accumulator[i-1];
    }
    trigger_count_accumulator[0] = trigger_counts;
    trigger_counts = 0;
}

float Tachometer::get_rpm(){

    if (tach_speed == TACH_LOW_SPEED){
        return rpm_measured_slow;
    } else if (tach_speed == TACH_HIGH_SPEED){
        return calc_rpm_fast();
    } else {return 0;}
}