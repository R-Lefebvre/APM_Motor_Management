#ifndef TEMPERATURE
#define TEMPERATURE

class Temperature{

    int pin_assignment;
    float filtered_V;

    public:
        Temperature(int);
        float get_temp_V(){return filtered_V;};
        void take_reading();

};

#endif //TEMPERATURE