

LAYER 
        NAME grids_subpoly
        GROUP grids
        TYPE line
        DATA /home/mapserv/grid/poly_subgrid/poly_subgrid
        FILTER ( '[SUFFIX]' = 'A' or '[SUFFIX]' = 'D' )
        STATUS ON  
        MAXSCALEDENOM 4000000
        CLASS
         STYLE
        SIZE 2
        PATTERN 4 12 END
        COLOR 131 245 44
        OPACITY 50
        END
        END
END


LAYER   
        NAME grids_poly
        GROUP grids
        TYPE line
        DATA /home/mapserv/grid/poly_grid/poly_grid
        STATUS ON
        MAXSCALEDENOM 4000000
        CLASS
        STYLE
        WIDTH 2
        COLOR 131 245 44
        END

        END
END
LAYER  
        NAME grids_point
        GROUP grids
        PROCESSING "LABEL_NO_CLIP=ON"
        TYPE point
        DATA /home/mapserv/grid/point_grid/point_grid
        STATUS ON
        MAXSCALEDENOM 4000000
        CLASS
        SYMBOL 0
        TEXT '[CONVENTION]_[CELL]'
        LABEL
        WRAP '_'
        ALIGN center
          COLOR  50 50 50
          OUTLINECOLOR 255 255 255
          FONT "sansb"
          TYPE truetype
          SIZE 10
          ANGLE 0
          POSITION CC
          PARTIALS true
        END

        END
END

