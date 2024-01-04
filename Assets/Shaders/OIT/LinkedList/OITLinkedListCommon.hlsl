#ifndef OITCOMMON_LINKEDLIST_INCLUDED
#define OITCOMMON_LINKEDLIST_INCLUDED

#define SIZEOF_UINT 4
#define MAX_NUM_FRAGS 16

struct FragmentAndLinkBuffer_STRUCT
{
    uint color;
    uint depth;
    uint next;
};

#endif //OITCOMMON_LINKEDLIST_INCLUDED
