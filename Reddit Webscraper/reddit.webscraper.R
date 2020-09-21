library(tidyverse)
library(RSelenium)
library(rvest)
library(xml2)
library(lubridate)
#XPath is the only locator that can iterate DOM upwards. This lets you use selectors like //div[.//h5[text()='header']], 
#which means that you can take div, which contains h5 with text "header."
#/comments/iuq94w/how_have_5_whole_months_passed/


#This function fetches data from the HTML using xpath
#It fetches:
#Main post, score, and date
#Comments, their scores and dates
get.discussion.data <- function(html.discussion, url.id)
{
  xpath <- paste0("//div[contains(@id, 't3_", url.id,"')]//p")
  main.post <- rvest::html_nodes(discussion.htmfindl, xpath = xpath) %>%
    rvest::html_text(trim = T) %>%
    paste(collapse = " ")  #Ensure that multiple paragraphs are collapsed into a single row
  
  main.date <- rvest::html_node(discussion.html, xpath = "//a[contains(@data-click-id, 'timestamp')]") %>%
    rvest::html_text(trim = T)
  
  main.title <- rvest::html_node(discussion.html, xpath = "//h1") %>%
    rvest::html_text(trim = T)
  
  main.score <- rvest::html_node(discussion.html, xpath = "//div[contains(@class, '_1rZYMD_4xY3gRcSS3p8ODO')]") %>%
    rvest::html_text(trim = T)
  
  comment.xpath <- "//div[contains(@class, 'uI_hDmU5GSiudtABRz_37')]//div[contains(@class, '_3cjCphgls6DH-irkVaA0GM')]"
  comment.posts <- rvest::html_nodes(discussion.html, xpath = comment.xpath) %>%
    rvest::html_text(trim = T) %>%
    dplyr::tibble(comment = .) 
  #Separated paragraphs will have the first and last word conjoined without a space, slight issue, but not anything serious
    
  score.xpath <- "//div[contains(@class, 'uI_hDmU5GSiudtABRz_37')]//span[contains(@class, '_2ETuFsVzMBxiHia6HfJCTQ _3_GZIIN1xcMEC5AVuv4kfa')]"
  comment.scores <- rvest::html_nodes(discussion.html, xpath = score.xpath) %>%
    rvest::html_text(trim = T) %>%
    dplyr::tibble(score = .) %>%
    dplyr::filter(score != "·")
  
  #If the lengths of each tibble for score and comments are mismatched an error will be thrown
  #If the number of comments is greater than the number of scores recorded, the bottom of scores is appended with NULL values until 
    #the length matches
  #Else, if the number of scores is greater than the number of comments recorders, the extraneous scores are cut out of the tibble
  if(nrow(comment.posts) > nrow(comment.scores))
  {
    difference <- nrow(comment.posts) - nrow(comment.scores)
    
    additional.values <- rep(list(NULL), difference) %>%
      as.character() %>%
      dplyr::tibble(score = .)
    
    comment.scores <- comment.scores %>%
      dplyr::bind_rows(additional.values)
  }
  else if(nrow(comment.scores) > nrow(comment.posts))
  {
    comment.scores <- comment.scores %>%
      slice(1:nrow(comment.posts))
  }
  
  #Bind columns and nest the data to be stored in our main dataframe
  comment.data <- NULL
  comment.data <- dplyr::tibble(comment.scores, comment.posts) %>%
    tidyr::nest(data = everything())
  
  #I'd like to directly create a tibble here, but it has a difficult tendency of
  #coercing comment.data to a list rather than nested data frame. AKA: Ruins everything
  discussion.data <- dplyr::bind_cols(date = main.date, score = main.score, title = main.title, post = main.post, comment.data = comment.data)

  return(discussion.data)
}

navigate.to.webpage <- function(remote_driver, discussion.url)
{
  #switch.second.window()
  #Try catch doesn't work well in R
  #Navigate to the given URL in the remote window
  remote_driver$navigate(discussion.url)

  #Find the button that says 'load more comments' and click it
  button.element <- remote_driver$findElement("xpath", "//button[contains(@class, '_2JBsHFobuapzGwpHQjrDlD j9NixHqtN2j8SKHcdJ0om _2nelDm85zKKmuD94NequP0')]")
  button.element$sendKeysToElement(list("\uE007"))
}

#Switches focus of the remote driver to the first tab
switch.first.window <- function()
{
  first.window <- remote_driver$getWindowHandles()[[1]]
  remote_driver$switchToWindow(first.window)
}

#Switches focus of the remote driver to the second tab
switch.second.window <- function()
{
  second.window <- remote_driver$getWindowHandles()[[2]]
  remote_driver$switchToWindow(second.window)
}


# Main Body ---------------------------------------------------------------
reddit.urls <- readr::read_csv("reddit.url.data.csv") %>%
  dplyr::select(2)

remote_driver <- RSelenium::remoteDriver(remoteServerAddr = "localhost", port = 4444L, browserName = "firefox")
remote_driver$open()
remote_driver$navigate("https://www.reddit.com/r/stopdrinking/new/")

reddit.html <- remote_driver$getPageSource()[[1]] %>%
  xml2::read_html()

bottomElem <- remote_driver$findElement("css", "body")
bottomElem$sendKeysToElement(list(key = "end"))

i <- 330

#Declared here for ease of understanding, not needed
#These data frames are used to store respective data points.
reddit.data <- dplyr::tibble()
discussion.data <- dplyr::tibble()
switch.second.window()
repeat
{
  if(remote_driver$getCurrentWindowHandle() == remote_driver$getWindowHandles()[[1]])
  {
    switch.second.window()
  }
  #To do - going to need to navigate and click view entire discussion, posts will show but scores won't
  discussion.url <- rvest::html_nodes(reddit.html, xpath = "//a[contains(@data-click-id, 'timestamp')]") %>%
    rvest::html_attr('href') 
  

  navigate.to.webpage(remote_driver, discussion.url)
  
  #discussion.html <- remote_driver$getPageSource()[[1]] %>%
    #::read_html() #This is my major slowdown, reading the HTML of every single post
  #Don't see a way around it
  discussion.html <- remote_driver$getPageSource()[[1]] %>%
    xml2::read_html()
  
  tryCatch({
    url.id <- strsplit(discussion.url, "/")[[1]][[7]]
  },
  finally = {
    next
  })
  discussion.data <- get.discussion.data(discussion.html, url.id)
 
  #Bind data together
  #//////////////////////////////////////////////////////
  reddit.data <- reddit.data %>%
    dplyr::bind_rows(discussion.data)
  
  i <- i + 1
  print(i)
  if (i %% 19 == 0)
  {
    switch.first.window()
    
    bottomElem <- remote_driver$findElement("css", "body")
    bottomElem$sendKeysToElement(list(key = "end"))
    
    Sys.sleep(3)
    
    reddit.html <- remote_driver$getPageSource()[[1]] %>%
      xml2::read_html()
    
    switch.second.window()
  }
  
}

saveRDS(reddit.data, "reddit.stop.drinking.2020.09.20")


# Main Body 2 - Method 2: From URL ----------------------------------------
#Open connection
remote_driver <- RSelenium::remoteDriver(remoteServerAddr = "localhost", port = 4444L, browserName = "firefox")
remote_driver$open()

#Create empty data frames that will be populated
reddit.data <- dplyr::tibble()
discussion.data <- dplyr::tibble()

#For every URL in our dataset fetched by the python script, extract data
for(index in 1:nrow(reddit.urls))
{
  
  #Get one URL at a time
  discussion.url <- reddit.urls[[1]][[index]]
  
  #If https does not exist as a substring, it isn't a URL
  #Continue with navigate.to.webpage() if it exists as a substring
  #Continue to the top of the loop otherwise and go to the next URL
  if(grepl("https", discussion.url))
  {
    navigate.to.webpage(remote_driver, discussion.url)
  }
  else {
    index <- index + 1
    next
  }

  #Get the HTML from the now loaded webpage
  discussion.html <- remote_driver$getPageSource()[[1]] %>%
    xml2::read_html()
  
  #Extract an ID found in each URL, these ID's combined with the string 't3_'
    #to find the div-class of the main post body
  url.id <- strsplit(discussion.url, "/")[[1]][[7]]
  
  #Retrieve data
  discussion.data <- get.discussion.data(discussion.html, url.id)
  
  #Bind data together
  #//////////////////////////////////////////////////////
  reddit.data <- reddit.data %>%
    dplyr::bind_rows(discussion.data)
  
  #Increment and show progress
  index <- index + 1
  print(index)
}


