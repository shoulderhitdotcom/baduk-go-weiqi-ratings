library(png)
library(imager)

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
        shiny::actionButton("button", label="Submit and Next")
    )
)


server <- function(input, output, session) {
    # Generate an image with black lines every 10 pixels
    output$image1 <- renderImage({
        input$button
        # Get width and height of image output
        width  <- session$clientData$output_image1_width
        height <- session$clientData$output_image1_height
        
        img <- imager::load.image("C:/data/2021-06-27_17-10-09.png")

        di = dim(img)
        print(di)

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
    
    observeEvent(input$button, {
        print(input$image_brush)
    })

    output$brush_info <- renderPrint({
        cat("input$image_brush:\n")
        str(input$image_brush)
    })
}

shinyApp(ui, server)
