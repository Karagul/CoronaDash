## app.R ##
function(input, output, session) {
  
  # Load scripts/modules -----
  
  # reading data
  source("01_scripts/read_data.R")
  source("01_scripts/aggregate_data.R")
  
  # forecasting
  source("01_scripts/forecasting.R")
 
  # menu -----
  output$Side_dash <- renderMenu({
    
    sidebarMenu(
      id = "sideBar_Menu",
      menuItem("COVID-19 Forecasting",
               icon = icon("chart-line"),
               tabName = "corTab",
               startExpanded = F,
               selected = T
               ),
      menuItem("COVID-19 World agg.",
               icon = icon("globe"),
               tabName = "worldTab",
               startExpanded = F,
               selected = F
               )
      )
  })
  
  # # text for accounts
  # output$text_accounts <- renderUI({
  #   HTML(paste("Links for my twitter, linkedin and github accounts.",
  #              sep=""))
  # })
  
  # informative text of this app -----
  output$informative_text <- renderUI({
    
    tags$html(tags$p("This application is only for informative purposes,
                     how the COVID-19 virus can spread over time for a defined country and period of days (cases and deaths)."),
              tags$p("Data are coming from",
                     tags$a(href = 'https://www.ecdc.europa.eu/en/publications-data/download-todays-data-geographic-distribution-covid-19-cases-worldwide',
                            target="_blank", "European Centre for Disease Prevention and Control.")),
              tags$p("The forecasting model is the ETS (Exponential smoothing) implemented in a smooth R package,
                      so only historical data of target time series are used.
                      For total cumulative confirmed cases, the fully multiplicative model is used.
                      For total cumulative death cases, the fully additive/multiplicative model is used."),
              tags$p("The forecasting model applied on the Covid-19 use case was inspired by",
                     tags$a(href = 'https://twitter.com/fotpetr',
                            target="_blank", "Fotios Petropoulos tweets.")),
              tags$p("An author of this app currently works as a Data Scientist for start-up",
                      tags$a(href = 'https://powerex.io/',
                      target="_blank", "PowereX.")),
              tags$p("Take care of yourself!")
              )
    
  })
  
  # read the data ----
  data_corona <- reactive({
    
    data_res <- read_data()
    
    data_res
    
  })
  
  # Country selector -----
  output$selector_country <- renderUI({
    
    pickerInput(
      inputId = "country",
      label = "Pick a country:", 
      choices = data_corona()[, unique(Country)],
      selected = "United_States_of_America",
      options = list(
        `live-search` = TRUE,
         style = "btn-info",
         maxOptions = 7
        )
      )
    
  })
  
  # N days forecast slider ----
  output$slider_n_days_forec <- renderUI({
    
    sliderInput(
      inputId = "n_days_forec", 
      label = "Set how many days ahead to create a forecast for:",
      min = 1,
      max = 30,
      value = 7
    )
    
  })
  
  # Subset data by a country ----
  data_country <- reactive({
    
    shiny::req(input$country)
    
    data_res <- copy(data_corona()[.(input$country), on = .(Country)])
    
    data_res
    
  })
  
  # Value boxes of statistics -----
  
  output$valuebox_total_cases <- renderValueBox({
    
    valueBox(
      data_country()[.N, Cases_cumsum],
      "Total confirmed cases",
      icon = icon("ambulance"),
      color = "yellow"
    )
    
  })
  
  output$valuebox_total_deaths <- renderValueBox({
    
    valueBox(
      data_country()[.N, Deaths_cumsum],
      "Total confirmed deaths",
      icon = icon("skull"),
      color = "red"
    )
    
  })
  
  output$valuebox_death_rate <- renderValueBox({
    
    valueBox(
      paste0(round(data_country()[.N, Deaths_cumsum]/data_country()[.N, Cases_cumsum], digits = 4)*100, "%"),
      "Death rate",
      icon = icon("exclamation-triangle"),
      color = "maroon"
    )
    
  })
  
  
  # Show cases of the selected country ----
  output$dygraph_country_cases <- renderDygraph({
    
    shiny::req(input$country)
    
    dygraph(data_country()[, .(DateRep, 'Cases cumulative' = Cases_cumsum, Cases)],
            main = input$country) %>%
      # dyAxis("y", label = "Cases") %>%
      dyRangeSelector(dateWindow = c(data_country()[, max(DateRep) - 10], data_country()[, max(DateRep) + 1]),
                      fillColor = "#5bc0de", strokeColor = "#222d32") %>%
      dyOptions(useDataTimezone = TRUE, strokeWidth = 2,
                fillGraph = TRUE, fillAlpha = 0.4,
                drawPoints = TRUE, pointSize = 3,
                pointShape = "circle",
                colors = c("#5bc0de", "#228b22")) %>%
      dyHighlight(highlightSeriesOpts = list(strokeWidth = 2.5, pointSize = 4)) %>%
      dyLegend(width = 400, show = "always")
    
  })
  
  # Show deaths of the selected country ----
  output$dygraph_country_deaths <- renderDygraph({
    
    shiny::req(input$country)
    
    dygraph(data_country()[, .(DateRep, 'Deaths cumulative' = Deaths_cumsum, Deaths)],
            main = input$country) %>%
      # dyAxis("y", label = "Deaths") %>%
      dyRangeSelector(dateWindow = c(data_country()[, max(DateRep) - 10], data_country()[, max(DateRep) + 1]),
                      fillColor = "#5bc0de", strokeColor = "#222d32") %>%
      dyOptions(useDataTimezone = TRUE, strokeWidth = 2,
                fillGraph = TRUE, fillAlpha = 0.4,
                drawPoints = TRUE, pointSize = 3,
                pointShape = "circle",
                colors = c("#5bc0de", "#228b22")) %>%
      dyHighlight(highlightSeriesOpts = list(strokeWidth = 2.5, pointSize = 4)) %>%
      dyLegend(width = 400, show = "always")
    
  })
  
  #### Compute forecasts --------
  
  # Forecasting Cases cumulative -----
  data_cases_cumsum_forec <- reactive({
    
    req(input$country, input$n_days_forec)
    
    data_res <- copy(data_country())
    
    data_forec <- forec_cases_cumsum(data_res, input$n_days_forec)
    
    data_res <- rbindlist(list(
      data_res,
      data.table(DateRep = seq.Date(data_res[, max(DateRep) + 1],
                                    data_res[, max(DateRep) + input$n_days_forec],
                                    by = 1),
                 Cases_cumsum_mean = round(data_forec$forecast, digits = 0),
                 Cases_cumsum_lwr = floor(data_forec$forecast),
                 Cases_cumsum_upr = data_forec$upper
                 )
    ), fill = TRUE, use.names = TRUE
    )
    
    data_res[, Model := data_forec$model]
    
    data_res
    
  })
  
  # Show forecasted cases of the selected country ----
  output$dygraph_country_cases_forecast <- renderDygraph({
    
    shiny::req(input$country, input$n_days_forec)
    
    data_res <- copy(data_cases_cumsum_forec())
    
    dygraph(data_res[, .(DateRep, 'Cases cumulative' = Cases_cumsum,
                         Cases_cumsum_mean, Cases_cumsum_lwr, Cases_cumsum_upr)],
            main = paste0(input$country,
                          ", model: ",
                          data_res[, unique(Model)])) %>%
      # dyAxis("y", label = "Cases - cumulative") %>%
      dySeries('Cases cumulative') %>%
      dySeries(c("Cases_cumsum_lwr", "Cases_cumsum_mean", "Cases_cumsum_upr"),
               label = "Cases cumulative - forecast") %>%
      dyRangeSelector(dateWindow = c(data_res[, max(DateRep) - input$n_days_forec - 7],
                                     data_res[, max(DateRep) + 1]),
                      fillColor = "#5bc0de", strokeColor = "#222d32") %>%
      dyOptions(useDataTimezone = TRUE, strokeWidth = 2,
                fillGraph = TRUE, fillAlpha = 0.4,
                drawPoints = TRUE, pointSize = 3,
                pointShape = "circle",
                colors = c("#5bc0de", "#228b22")) %>%
      dyHighlight(highlightSeriesOpts = list(strokeWidth = 2.5, pointSize = 4)) %>%
      dyEvent(data_res[is.na(Cases_cumsum_mean), max(DateRep)],
              "Forecasting origin", labelLoc = "bottom") %>%
      dyLegend(width = 400, show = "always")
    
  })
  
  # Forecasting Deaths cumulative -----
  data_deaths_cumsum_forec <- reactive({
    
    req(input$country, input$n_days_forec)
    
    data_res <- copy(data_country())
    
    data_forec <- forec_deaths_cumsum(data_res, input$n_days_forec)
    
    data_res <- rbindlist(list(
      data_res,
      data.table(DateRep = seq.Date(data_res[, max(DateRep) + 1],
                                    data_res[, max(DateRep) + input$n_days_forec],
                                    by = 1),
                 Deaths_cumsum_mean = round(data_forec$forecast, digits = 0),
                 Deaths_cumsum_lwr = floor(data_forec$forecast),
                 Deaths_cumsum_upr = data_forec$upper
      )
    ), fill = TRUE, use.names = TRUE
    )
    
    data_res[, Model := data_forec$model]
    
    data_res
    
  })
  
  # Show forecasted deaths of the selected country ----
  output$dygraph_country_deaths_forecast <- renderDygraph({
    
    shiny::req(input$country, input$n_days_forec)
    
    data_res <- copy(data_deaths_cumsum_forec())
    
    dygraph(data_res[, .(DateRep, 'Deaths cumulative' = Deaths_cumsum,
                         Deaths_cumsum_mean, Deaths_cumsum_lwr, Deaths_cumsum_upr)],
            main = paste0(input$country,
                          ", model: ",
                          data_res[, unique(Model)])) %>%
      # dyAxis("y", label = "Deaths - cumulative") %>%
      dySeries('Deaths cumulative') %>%
      dySeries(c("Deaths_cumsum_lwr", "Deaths_cumsum_mean", "Deaths_cumsum_upr"),
               label = "Deaths cumulative - forecast") %>%
      dyRangeSelector(dateWindow = c(data_res[, max(DateRep) - input$n_days_forec - 7],
                                     data_res[, max(DateRep) + 1]),
                      fillColor = "#5bc0de", strokeColor = "#222d32") %>%
      dyOptions(useDataTimezone = TRUE, strokeWidth = 2,
                fillGraph = TRUE, fillAlpha = 0.4,
                drawPoints = TRUE, pointSize = 3,
                pointShape = "circle",
                colors = c("#5bc0de", "#228b22")) %>%
      dyHighlight(highlightSeriesOpts = list(strokeWidth = 2.5, pointSize = 4)) %>%
      dyEvent(data_res[is.na(Deaths_cumsum_mean), max(DateRep)],
              "Forecasting origin", labelLoc = "bottom") %>%
      dyLegend(width = 400, show = "always")
    
  })
  
  #### World aggregated -----------
  
  data_world <- reactive({
    
    data_res <- aggregate_data(data_corona())
    
    data_res
    
  })
  
  # Value boxes of world statistics -----
  
  output$valuebox_total_cases_world <- renderValueBox({
    
    valueBox(
      data_world()[.N, Cases_cumsum],
      "Total confirmed cases",
      icon = icon("ambulance"),
      color = "yellow"
    )
    
  })
  
  output$valuebox_total_deaths_world <- renderValueBox({
    
    valueBox(
      data_world()[.N, Deaths_cumsum],
      "Total confirmed deaths",
      icon = icon("skull"),
      color = "red"
    )
    
  })
  
  output$valuebox_death_rate_world <- renderValueBox({
    
    valueBox(
      paste0(round(data_world()[.N, Deaths_cumsum]/data_world()[.N, Cases_cumsum], digits = 4)*100, "%"),
      "Death rate",
      icon = icon("exclamation-triangle"),
      color = "maroon"
    )
    
  })

  # Show cases of the world ----
  output$dygraph_world_cases <- renderDygraph({
    
    dygraph(data_world()[, .(DateRep, 'Cases cumulative' = Cases_cumsum, Cases)],
            main = "World") %>%
      # dyAxis("y", label = "Cases") %>%
      dyRangeSelector(dateWindow = c(data_world()[, max(DateRep) - 20], data_country()[, max(DateRep) + 1]),
                      fillColor = "#5bc0de", strokeColor = "#222d32") %>%
      dyOptions(useDataTimezone = TRUE, strokeWidth = 2,
                fillGraph = TRUE, fillAlpha = 0.4,
                drawPoints = TRUE, pointSize = 3,
                pointShape = "circle",
                colors = c("#5bc0de", "#228b22")) %>%
      dyHighlight(highlightSeriesOpts = list(strokeWidth = 2.5, pointSize = 4)) %>%
      dyLegend(width = 400, show = "always")
    
  })
  
  # Show deaths of the world ----
  output$dygraph_world_deaths <- renderDygraph({

    dygraph(data_world()[, .(DateRep, 'Deaths cumulative' = Deaths_cumsum, Deaths)],
            main = "World") %>%
      # dyAxis("y", label = "Deaths") %>%
      dyRangeSelector(dateWindow = c(data_world()[, max(DateRep) - 20], data_country()[, max(DateRep) + 1]),
                      fillColor = "#5bc0de", strokeColor = "#222d32") %>%
      dyOptions(useDataTimezone = TRUE, strokeWidth = 2,
                fillGraph = TRUE, fillAlpha = 0.4,
                drawPoints = TRUE, pointSize = 3,
                pointShape = "circle",
                colors = c("#5bc0de", "#228b22")) %>%
      dyHighlight(highlightSeriesOpts = list(strokeWidth = 2.5, pointSize = 4)) %>%
      dyLegend(width = 400, show = "always")
    
  })
  
  # Forecasting Cases cumulative world -----
  data_cases_cumsum_forec_world <- reactive({
    
    data_res <- copy(data_world())
    
    data_forec <- forec_cases_cumsum(data_res, 10)
    
    data_res <- rbindlist(list(
      data_res,
      data.table(DateRep = seq.Date(data_res[, max(DateRep) + 1],
                                    data_res[, max(DateRep) + 10],
                                    by = 1),
                 Cases_cumsum_mean = round(data_forec$forecast, digits = 0),
                 Cases_cumsum_lwr = floor(data_forec$forecast),
                 Cases_cumsum_upr = data_forec$upper
      )
    ), fill = TRUE, use.names = TRUE
    )
    
    data_res[, Model := data_forec$model]
    
    data_res
    
  })
  
  # Show forecasted cases of the world ----
  output$dygraph_world_cases_forecast <- renderDygraph({
    
    data_res <- copy(data_cases_cumsum_forec_world())
    
    dygraph(data_res[, .(DateRep, 'Cases cumulative' = Cases_cumsum,
                         Cases_cumsum_mean, Cases_cumsum_lwr, Cases_cumsum_upr)],
            main = paste0("World",
                          ", model: ",
                          data_res[, unique(Model)])) %>%
      # dyAxis("y", label = "Cases - cumulative") %>%
      dySeries('Cases cumulative') %>%
      dySeries(c("Cases_cumsum_lwr", "Cases_cumsum_mean", "Cases_cumsum_upr"),
               label = "Cases cumulative - forecast") %>%
      dyRangeSelector(dateWindow = c(data_res[, max(DateRep) - 10 - 7],
                                     data_res[, max(DateRep) + 1]),
                      fillColor = "#5bc0de", strokeColor = "#222d32") %>%
      dyOptions(useDataTimezone = TRUE, strokeWidth = 2,
                fillGraph = TRUE, fillAlpha = 0.4,
                drawPoints = TRUE, pointSize = 3,
                pointShape = "circle",
                colors = c("#5bc0de", "#228b22")) %>%
      dyHighlight(highlightSeriesOpts = list(strokeWidth = 2.5, pointSize = 4)) %>%
      dyEvent(data_res[is.na(Cases_cumsum_mean), max(DateRep)],
              "Forecasting origin", labelLoc = "bottom") %>%
      dyLegend(width = 400, show = "always")
    
  })
  
  # Forecasting Deaths cumulative for world -----
  data_deaths_cumsum_forec_world <- reactive({
    
    data_res <- copy(data_world())
    
    data_forec <- forec_deaths_cumsum(data_res, 10)
    
    data_res <- rbindlist(list(
      data_res,
      data.table(DateRep = seq.Date(data_res[, max(DateRep) + 1],
                                    data_res[, max(DateRep) + 10],
                                    by = 1),
                 Deaths_cumsum_mean = round(data_forec$forecast, digits = 0),
                 Deaths_cumsum_lwr = floor(data_forec$forecast),
                 Deaths_cumsum_upr = data_forec$upper
      )
    ), fill = TRUE, use.names = TRUE
    )
    
    data_res[, Model := data_forec$model]
    
    data_res
    
  })
  
  # Show forecasted deaths of the world ----
  output$dygraph_world_deaths_forecast <- renderDygraph({

    data_res <- copy(data_deaths_cumsum_forec_world())
    
    dygraph(data_res[, .(DateRep, 'Deaths cumulative' = Deaths_cumsum,
                         Deaths_cumsum_mean, Deaths_cumsum_lwr, Deaths_cumsum_upr)],
            main = paste0("World",
                          ", model: ",
                          data_res[, unique(Model)])) %>%
      # dyAxis("y", label = "Deaths - cumulative") %>%
      dySeries('Deaths cumulative') %>%
      dySeries(c("Deaths_cumsum_lwr", "Deaths_cumsum_mean", "Deaths_cumsum_upr"),
               label = "Deaths cumulative - forecast") %>%
      dyRangeSelector(dateWindow = c(data_res[, max(DateRep) - 10 - 7],
                                     data_res[, max(DateRep) + 1]),
                      fillColor = "#5bc0de", strokeColor = "#222d32") %>%
      dyOptions(useDataTimezone = TRUE, strokeWidth = 2,
                fillGraph = TRUE, fillAlpha = 0.4,
                drawPoints = TRUE, pointSize = 3,
                pointShape = "circle",
                colors = c("#5bc0de", "#228b22")) %>%
      dyHighlight(highlightSeriesOpts = list(strokeWidth = 2.5, pointSize = 4)) %>%
      dyEvent(data_res[is.na(Deaths_cumsum_mean), max(DateRep)],
              "Forecasting origin", labelLoc = "bottom") %>%
      dyLegend(width = 400, show = "always")
    
  })
  
}