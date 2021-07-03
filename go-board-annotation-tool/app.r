library(imager)

IMGPATH = "C:/data/weiqi-board-for-ml"

ui <- fluidPage(
    tags$script(HTML("$(function(){ 
      $(document).keyup(function(e) {
      if (e.which == 32) {
        $('#button').click()
      }
      });
      })")),
    
    shiny::titlePanel("World's simplest image annotation tool with Shiny"),
    
    fluidRow(
        column(width = 12,
               br(),
               imageOutput("image1", width = 800, height=450,
                           brush = brushOpts(
                               id = "image_brush",
                               resetOnNew = TRUE
                           )
               ),
               br()
        )
    ),
    fluidRow(
        shiny::actionButton("button", label="Submit and Next"),
        shiny::actionButton("button_no_board", label="No Go board")
    )
)


server <- function(input, output, session) {
    current_img_path <- reactiveVal(list.files(IMGPATH, pattern=".png$")[1])
  
    # Generate an image with black lines every 10 pixels
    output$image1 <- renderImage({
        input$button
        # Get width and height of image output
        width  <- session$clientData$output_image1_width
        height <- session$clientData$output_image1_height
  
        img <- imager::load.image(file.path(IMGPATH, current_img_path()))

        di = dim(img)
        sz = 800
        img = imager::resize(img, size_x = sz, size_y = di[2]*sz/di[1])
        
        # Write it to a temporary file
        outfile <- tempfile(fileext = ".png")
        imager::save.image(img, outfile)
        
        # Return a list containing information about the image
        list(
            src = outfile,
            contentType = "image/png",
            width = width,
            height = height,
            alt = "This is alternate text"
        )
    })
    
    go_to_next <- function() {
      files = list.files(IMGPATH, pattern=".png$")
      next_file = which(files == current_img_path()) + 1
      
      if (next_file > length(files)) {
        next_file = 1
      }
      
      current_img_path(files[next_file])
    }
    
    observeEvent(input$button, {
      fp = file.path(IMGPATH, "annotations", current_img_path())
      df = data.frame(input$image_brush[c("xmin", "xmax", "ymin", "ymax")])
      df$has_go_board = 1
      data.table::fwrite(df, paste0(fp, ".csv"))
      
      go_to_next()
    })
    
    observeEvent(input$button_no_board, {
      fp = file.path(IMGPATH, "annotations", current_img_path())
      df =  data.frame(has_go_board = 0)
      data.table::fwrite(df, paste0(fp, ".csv"))
      
      go_to_next()
    })
}

shinyApp(ui, server)
