#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(shinythemes)
library(ggplot2)
library(tidyverse)
library(janitor)
library(memoise)
library(rsconnect)
library(tm)
library(wordcloud2)
library(wordcloud)
library(randomForest)
library(slickR)

# Read in my data here

storesearch <- read.csv("raw_data/storefront_searches_2020-02-29_2020-03-07.csv") %>%
    clean_names()

visits <- read.csv("raw_data/visits_2019-01-01_2019-12-31.csv") %>%
    clean_names()

sales <- read.csv("raw_data/sales_2019-01-01_2019-12-31 (1).csv") %>%
  clean_names()

# Created a few edits to the data

purchases <- visits %>%
  filter(day == "2019-01-01"| day == "2019-02-01" | day == "2019-03-01" |  day == "2019-04-01" |  day ==
           "2019-05-01" | day == "2019-06-01" | day == "2019-07-01" | day == "2019-08-01" |  
           day == "2019-09-01" |  day == "2019-10-01" |  day == "2019-11-01" |  day == "2019-12-01") %>% 
  pivot_longer(cols = c(total_sessions, total_carts, total_checkouts, total_orders_placed, total_conversion), names_to = "action")


purchase_history <- sales %>%
  select(product_title, product_type, customer_id, net_quantity, ordered_item_quantity) %>%
  group_by(customer_id) %>%
  count(., customer_id, name = "repeat_purchase") %>%
  arrange(desc(repeat_purchase)) 

total_purchase <- purchase_history %>%
  ungroup() %>%
  summarize(total_purchases = sum(repeat_purchase))

# Createed new columns that showed customers purchases and if they purchased certain items

options(scipen = 999)
ml_sales <- sales %>%
  mutate(battery = case_when(str_detect(product_title, regex("battery", ignore_case = TRUE)) ~ 1, TRUE ~ 0),
         gear = case_when(str_detect(product_title, regex("gear", ignore_case = TRUE)) ~ 1, TRUE ~ 0),
         charger = case_when(str_detect(product_title, regex("charger", ignore_case = TRUE)) ~ 1, TRUE ~ 0),
         control = case_when(str_detect(product_title, regex("control", ignore_case = TRUE)) ~ 1, TRUE ~ 0),
         drone = case_when(str_detect(product_title, regex("drone", ignore_case = TRUE)) ~ 1, TRUE ~ 0),
         parts = case_when(str_detect(product_title, regex("parts", ignore_case = TRUE)) ~ 1, TRUE ~ 0)
  ) %>%
  select(customer_id, battery, gear, charger, control, drone, parts) %>%
  group_by(customer_id) %>%
  summarise_all(funs(sum))

# Cleaned my data again to make sure it's a 0 or 1 that shows

cleaned_ml <- ml_sales %>%
  mutate(battery_true = ifelse(battery != 0, 1, battery),
         gear_true = ifelse(gear != 0, 1, gear),
         charger_true = ifelse(charger != 0, 1, charger),
         control_true = ifelse(control != 0, 1, control),
         drone_true = ifelse(drone != 0, 1, drone),
         parts_true = ifelse(parts != 0, 1, parts)) %>%
  select(battery_true, gear_true, charger_true, control_true, drone_true, parts_true)

# Below is the code I used to read in each of my randomForests and saved it as
# an RDS.  I kept this code to remember how it is done for the future

#predict_battery <- randomForest(factor(parts_true) ~ battery_true + gear_true + charger_true + control_true + drone_true,
                                #data =  cleaned_ml)
#saveRDS(predict_battery, file = "predict_battery.rds")

predict_battery = readRDS("predict_battery.rds")


#predict_gear <- randomForest(factor(gear_true) ~ battery_true + parts_true + charger_true + control_true + drone_true,
                              #data =  cleaned_ml)
#saveRDS(predict_gear, file = "predict_gear.rds")
predict_gear = readRDS("predict_gear.rds")
 
 
#predict_parts <- randomForest(factor(parts_true) ~ battery_true + gear_true + charger_true + control_true + drone_true,
                              #data =  cleaned_ml)
#saveRDS(predict_parts, file = "predict_parts.rds")
predict_parts = readRDS("predict_parts.rds")

#predict_charger <- randomForest(factor(charger_true) ~ battery_true + gear_true + parts_true + control_true + drone_true,
                                #data =  cleaned_ml)
#saveRDS(predict_charger, file = "predict_charger.rds")
predict_charger = readRDS("predict_charger.rds")

# predict_control <- randomForest(factor(control_true) ~ battery_true + gear_true + parts_true + charger_true + drone_true,
#                                  data =  cleaned_ml)
#  saveRDS(predict_control, file = "predict_control.rds")

 predict_control = readRDS("predict_control.rds")
 
 predict_drone <- randomForest(factor(drone_true) ~ battery_true + gear_true + parts_true + charger_true + control_true,
                               data =  cleaned_ml)
 
 saveRDS(predict_drone, file = "predict_drone.rds")
 predict_drone = readRDS("predict_drone.rds")


# This is for my wordcloud that I found a similar code online

text <- storesearch$original_query
# Create a corpus  
docs <- Corpus(VectorSource(text))

docs <- docs %>%
  tm_map(removeNumbers) %>%
  tm_map(removePunctuation) %>%
  tm_map(stripWhitespace)
docs <- tm_map(docs, content_transformer(tolower))
docs <- tm_map(docs, removeWords, stopwords("english"))

dtm <- TermDocumentMatrix(docs) 
matrix <- as.matrix(dtm) 
words <- sort(rowSums(matrix),decreasing=TRUE) 
df <- data.frame(word = names(words),freq=words)

wordcloud(words = df$word, freq = df$freq, min.freq = 1,
          max.words=200, random.order=FALSE, rot.per=0.35,
          colors=brewer.pal(8, "Dark2"))

ui <- fluidPage(theme = shinytheme("flatly"), 
  
  navbarPage("Explore the data",
             tabPanel("Are people buying?",
                      #used tabset panel to create a panel within my overall panel 
                      tabsetPanel(
                        tabPanel("Exploring Purchase Behavior",
                                 
                                 #used sidebar panel to separate the sidebar from the main panel                                 
                                 sidebarPanel(
                                   
                                   selectInput("action", "Select an customer action:",
                                               choices = c("Visits site" = "total_sessions",
                                                           "Put item in cart" = "total_carts",
                                                           "Continue to checkout screen" = "total_checkouts",
                                                           "Order placed" = "total_orders_placed",
                                                           "Conversion rate" = "total_conversion")
                                   )))),

  fluidPage(                         
                           mainPanel(
                               h2("Exploring Sales and Customer Interaction"),
                               plotOutput("plot_1")
                           ))),
    
  tabPanel("Popular Searches",
           
      # Application title
      titlePanel("Most popular search words on e-commerce site"),
      
      sidebarLayout(
        # Sidebar with a slider and selection inputs
        sidebarPanel(
       
          hr(),
          sliderInput("freq",
                      "Minimum Frequency:",
                      min = 1,  max = 30, value = 5),
          sliderInput("max",
                      "Maximum Number of Words:",
                      min = 1,  max = 30,  value = 10)
        ),
        
     fluidPage(   
        # Show Word Cloud
        mainPanel(
          plotOutput("wordplot")
        )
      )))
    ,
    # Define UI (user interface) for application, which is the
    # formating/way the interface will look to users
    
    #used navbarpage to create a navbar shiny app set up, used tab panel to create
    #the tabs within my shiny app, within the first tab map I called imageoutput
    #referencing map, which I then specified in the server section below, inside the
    #second tab, about I used h4 to set a header and p to specify a paragraph of
    #text that I entered

                        tabPanel("Predicting Purchases?",
                                 tabsetPanel(
                                   tabPanel("Creating suggestions off of what people purchase",
                                    
                                    #Used select input within sidebar panel to create payment type choices 
                                    
                                    sidebarPanel(
                                       column(8, offset = 1,
                                              selectInput('battery', 'Battery', choices = list("Yes" = 1, "No" = 0)),
                                              selectInput('gear', 'Gear', choices = list("Yes" = 1, "No" = 0)),
                                              selectInput('charger', 'Charger', choices = list("Yes" = 1, "No" = 0)),
                                              selectInput('drone', 'Drone', choices = list("Yes" = 1, "No" = 0)),
                                              selectInput('parts', 'Parts', choices = list("Yes" = 1, "No" = 0)),
                                              selectInput('control', 'Control', choices = list("Yes" = 1, "No" = 0))
                                          
                                      )
                                   )),
                                
                                    #within main panel have plot output which corresponds with function in output section below
                                    
                                    mainPanel(
                                     textOutput("suggesteditems"),
                                     slickROutput("photos", width = "500px")
                                    ))),




# My about tab            
                tabPanel("About", 
                         titlePanel("About"),
                         h3("Project Background"),
                         p("Hello, and welcome to my Gov 1005 Final Project."),
                         h3("About Me"),
                         p("My name is Taylor Greenberg Goldy and I study Design Engineering in the Graduate School of Design and School of Engineering and Applied Sciences. This is the link for my repo:
https://github.com/taylorgreenberggoldy/final_project_2

The data I am using for this project is looking at the behavior of customers and interactions they have on a shopping website that I have access to. In this data, I'll be able to see how often people are shopping, what are they shopping for as well as what are they searching on the website for. Through this study, I can hopefully be able to make suggestions to how to improve the overal UX of the site to let people navigate it more thoroughly. I am slowly getting access to more of the data and will be able to add more files into this project however for now, these two provide sufficient data to get started.

To pull this data, I'm looking at shopify as well as google analytics that pulls basic measurements off of the website of the e-commerce site.

             You can reach me at taylorgg@mde.harvard.edu"))))

server <- function(input, output) {
  
  # Made this filter to 
    datareact <- reactive({
        visits %>%
            filter(day == "2019-01-01"| day == "2019-02-01" | day == "2019-03-01" |  day == "2019-04-01" |
                       day == "2019-05-01" | day == "2019-06-01" | day == "2019-07-01" | day == "2019-08-01" | 
                       day == "2019-09-01" |  day == "2019-10-01" |  day == "2019-11-01" |  day == "2019-12-01") %>% 
            pivot_longer(cols = c(total_sessions, total_carts, total_checkouts, total_orders_placed, 
                                  total_conversion), names_to = "action")
    })
    
    # Creating a plot for my first page on purchase history
    
    output$plot_1 <- renderPlot({

        purchases %>%
            filter(action == input$action) %>%
            ggplot(aes(x = day, y = value, fill = input$action))+
            geom_bar(stat = "identity", position = "dodge") +
            labs(title = "Shopping Turnover for Online Shop",
                 y = "Actions", x = "Month")+
            theme(axis.text.x=element_text(angle=45, hjust=1))
    })

     

      new_customer_tibble <- reactive({
  
      new_customer <- tibble(battery_true = input$battery, gear_true = input$gear, charger_true = input$charger, 
                       control_true = input$control, drone_true = input$drone, parts_true = input$parts)
})   

    output$suggesteditems <- renderText({


      new_customer <- new_customer_tibble()

# Data from above for machine learning model for purchase history


      batteryPrediction<-ifelse(as.numeric(predict(predict_battery, newdata = new_customer)[[1]]) == 1, "Battery ", "")
      gearPrediction<-ifelse(as.numeric(predict(predict_gear, newdata = new_customer)[[1]]) == 1, "Gear ", "")
      chargerPrediction<-ifelse(as.numeric(predict(predict_charger, newdata = new_customer)[[1]]) == 1, "Charger ", "")
      controlPrediction<-ifelse(as.numeric(predict(predict_control, newdata = new_customer)[[1]]) == 1, "Control ", "")
      dronePrediction<-ifelse(as.numeric(predict(predict_drone, newdata = new_customer)[[1]]) == 1, "Drone ", "")
      partsPrediction<-ifelse(as.numeric(predict(predict_parts, newdata = new_customer)[[1]]) == 1, "Parts ", "")

    
   itemList<-paste("Suggested items:", batteryPrediction, gearPrediction, chargerPrediction, controlPrediction, 
                   dronePrediction, partsPrediction)
    print(itemList)
    
 })

# My Teaching Fellow, Mitchell Kilborn was incredibly helping in walking me
# through how to make this model interactive

imglist <- reactive({
  
  new_customer <- new_customer_tibble()
  
  batteryPrediction<-ifelse(as.numeric(predict(predict_battery, newdata = new_customer)[[1]]) == 1, "battery", "")
  gearPrediction<-ifelse(as.numeric(predict(predict_gear, newdata = new_customer)[[1]]) == 1, "gear", "")
  chargerPrediction<-ifelse(as.numeric(predict(predict_charger, newdata = new_customer)[[1]]) == 1, "charger", "")
  controlPrediction<-ifelse(as.numeric(predict(predict_control, newdata = new_customer)[[1]]) == 1, "control", "")
  dronePrediction<-ifelse(as.numeric(predict(predict_drone, newdata = new_customer)[[1]]) == 1, "drone", "")
  partsPrediction<-ifelse(as.numeric(predict(predict_parts, newdata = new_customer)[[1]]) == 1, "parts", "")

# Below is what needed to be created to create an image output
  
  itemList<-paste(c(batteryPrediction, gearPrediction, chargerPrediction, controlPrediction, dronePrediction, partsPrediction), collapse = "|")
  
  imgs <- list.files("imgs/", pattern=".png", full.names = TRUE)
  imgs <- imgs[str_detect(imgs, itemList)]
  
})  

# After we created above, we can feed it into slickR

output$photos <- renderSlickR({
  imgs <- imglist()
  slickR(imgs)
  
})
  
      terms <- reactive({
        # Change when the "update" button is pressed...
        input$update
        # ...but not for anything else
        isolate({
          withProgress({
            setProgress(message = "Processing corpus...")
            getTermMatrix(input$original_query)
          })
        })
        text <- storesearch$original_query
        # Create a corpus  
        docs <- Corpus(VectorSource(text))
        
        docs <- docs %>%
          tm_map(removeNumbers) %>%
          tm_map(removePunctuation) %>%
          tm_map(stripWhitespace)
        docs <- tm_map(docs, content_transformer(tolower))
        docs <- tm_map(docs, removeWords, stopwords("english"))
        
        dtm <- TermDocumentMatrix(docs) 
        matrix <- as.matrix(dtm) 
        words <- sort(rowSums(matrix),decreasing=TRUE) 
        df <- data.frame(word = names(words),freq=words)
        
      })
      
      # Make the wordcloud drawing predictable during a session
      wordcloud_rep <- repeatable(wordcloud)
      
      output$wordplot <- renderPlot({
        #Create a vector containing only the text
        wordcloud(words = df$word, freq = df$freq, min.freq = input$freq,
                  max.words= input$max, random.order=FALSE, rot.per=0.35,
                  colors=brewer.pal(8, "Dark2"))
      })
    
}

# Run the application
shinyApp(ui = ui, server = server)
