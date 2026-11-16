typedef long long int64_t;
typedef struct Timing Timing;
Timing *getTiming(void);
struct Timing {
    unsigned int frameId;
    int64_t value;
};
