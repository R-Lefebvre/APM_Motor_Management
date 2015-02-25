#include <Temperature.h>
#include <Arduino.h>

// Constructor
Temperature::Temperature(uint8_t pin){
    pin_assignment = pin;
}

// To be called at 100Hz, takes measurement and applies simple LPF
void Temperature::take_reading(){
    // This does a simple low-pass filter on the temperature reading which can be quite noisy
    filtered_V = 0.99*filtered_V + 0.01*(3.3 * analogRead(pin_assignment)/1023);
}