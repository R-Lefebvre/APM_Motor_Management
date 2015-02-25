#ifndef TEMPERATURE
#define TEMPERATURE

#include "inttypes.h"

class Temperature{

    public:
        // Methods
        Temperature(uint8_t);                       // Constructor
        float get_temp_V(){return filtered_V;};     // Return filtered voltage reading
        void take_reading();                        // To be called at 100Hz, takes measurement and applies simple LPF

    private:
        uint8_t pin_assignment;                     // Analog input pin used on hardware
        float filtered_V;                           // filtered voltage

};

#endif //TEMPERATURE