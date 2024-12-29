package main

import "core:fmt"
import get_up_timer "./get_up_timer"

main :: proc() {

    fmt.println("Start Timer Get Up and Start Walking!...")
    get_up_timer.run( )
    fmt.println("...end Timer Get Up and Start Walking!")
}
