#ifndef TEMPERATURE
#define TEMPERATURE

#include "inttypes.h"

class Temperature{

    uint8_t pin_assignment;
    float filtered_V;

    public:
        Temperature(uint8_t);
        float get_temp_V(){return filtered_V;};
        void take_reading();

};

#endif //TEMPERATURE