#include <Tachometer.h>
#include <Arduino.h>

Tachometer::Tachometer(uint16_t pin_assignment, uint16_t speed){
    _tach_speed = speed;
    pinMode(pin_assignment, INPUT_PULLUP);
    _trigger_counts = 0;
    //_trigger_count_accumulator[] = {0,0,0,0,0,0,0,0,0,0};
}

// What to do on a timer capture ISR
void Tachometer::interrupt_function(){

    _trigger_time = micros();
    _trigger_counts++;
}    

// Method to calculate rpm on slow channel
float Tachometer::calc_ppm_slow(){
    return (_ppm_measured_slow + (60000000.0/(float)_trigger_timing))/2 ;        //Simple Low-pass Filter
}

// Method to calculate rpm on fast channel
float Tachometer::calc_ppm_fast(){
    uint16_t pulse_total = 0;
    for (uint8_t i = 0; i < 10; i++){
        pulse_total += _trigger_count_accumulator[i];
    }
    return pulse_total*600;
}

// Manages millis() overflow which upsets timing data
void Tachometer::timer_overflow_handler(){
    //we will throw out whatever data we have
    _trigger_time_old = 0;
    _trigger_time = 0;

    //and the next capture too
    _timing_overflow_trigger_skip = true;
}

// Call at 1000 Hz to check for new pulses, allows max PPM of 60,000
void Tachometer::check_pulses(uint32_t fl_timer){

    if (_tach_speed == TACH_HIGH_SPEED){
        return;
    }

    if ( (_trigger_time_old + (3 * _trigger_timing)) < fl_timer ){        // We have lost more than 1 expected pulse, start to decay the measured RPM
        _ppm_measured_slow *= 0.99;
        if (_ppm_measured_slow < 0){
            _ppm_measured_slow = 0;
        }
    }

    if (_trigger_time_old != _trigger_time){                              // We have new trigger_1_timing data to consume
        if (!_timing_overflow_trigger_skip){                             // If micros has not overflowed, we will calculate trigger_1_timing based on this data
            _trigger_timing_old = _trigger_timing;
            _trigger_timing = _trigger_time - _trigger_time_old;
            _ppm_measured_slow = calc_ppm_slow();
        } else {
            _timing_overflow_trigger_skip = false;                       // If micros has overflowed, reset the skip bit since we have thrown away this bad data
        }
        _trigger_time_old = _trigger_time;                                // In either case, we need to do this so we can look for new data
    }
}

// Call at 100 Hz to accumulate high speed pulses
void Tachometer::count_pulses(){

    for (uint8_t i = 9; i > 0; i--){
        _trigger_count_accumulator[i] = _trigger_count_accumulator[i-1];
    }
    _trigger_count_accumulator[0] = _trigger_counts;
    _trigger_counts = 0;
}

// Call to return RPM value
float Tachometer::get_rpm(){

    if (_tach_speed == TACH_LOW_SPEED){
        return _ppm_measured_slow;
    } else if (_tach_speed == TACH_HIGH_SPEED){
        return calc_ppm_fast();
    } else {return 0;}
}