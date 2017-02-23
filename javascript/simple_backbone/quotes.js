// A simple quote rendering application

// - Fetches quote database from resourse on app initialization
// - Paginates 15 results per page
// - Allows enumerated filter by theme
// - Allows free text quote search


const QUOTES_URL = "https://gist.githubusercontent.com/anonymous/8f61a8733ed7fa41c4ea/raw/1e90fd2741bb6310582e3822f59927eb535f6c73/quotes.json";
const RESULTS_PER_PAGE = 15;
const ANY_THEME = "any";


$(function(){
    // Define the Quote model with defaul attributes
    var Quote = Backbone.Model.extend({
        defaults: function() {
            return {
                source: "Anonymous",
                context: "an unknown work",
                quote: "an unknown quote",
                theme: null,
            };
        },
    });

    // Slices collection `values` by page, started at 1
    var paginate = function(values, page) {
        var start = (page - 1) * RESULTS_PER_PAGE;
        var end = page * RESULTS_PER_PAGE;
        return values.slice(start, end);
    };

    // A QuiteList is a collection of Quotes with filter and
    // pagination functionalities
    var QuoteList = Backbone.Collection.extend({
        model: Quote,

        // Value to filter by quote.theme, default "any" matches all
        // themes
        filterTheme: ANY_THEME,

        // Value to filter by substring of Quote.quote
        filterKeyword: "",

        // Save the current page state
        currentPage: 1,

        // Reset currentPage, to be called whenever filters change
        resetPage: function() {
            this.currentPage = 1;
        },

        // to be called whenever filters change
        incrementPage: function(increment) {
            this.currentPage += increment;
        },

        updateFilterKeyword: function(value) {
            Quotes.filterKeyword = value;
            this.resetPage();
        },

        updateFilterTheme: function(value) {
            Quotes.filterTheme = value;
            this.resetPage();
        },

        // Returns an array of Quote objects that match any themes or
        // keywords in internal state
        filtered: function() {
            var models;
            var filterKeyword = this.filterKeyword.toLowerCase();

            // Filter by theme
            if (this.filterTheme != ANY_THEME) {
                models = this.where({theme: this.filterTheme});
            } else {
                models = this.models;
            }

            // Filter by query term
            if (filterKeyword != "") {
                models = _.filter(models, function(model) {
                    var quote = model.get('quote').toLowerCase();
                    return quote.indexOf(filterKeyword) >= 0;
                });
            }

            return models;
        },

        // Returns pagination of filtered results
        visible: function() {
            return paginate(this.filtered(), this.currentPage)
        },

        // Returns the number of total pages rounded up that could
        // contain filtered results
        totalPages: function() {
            return Math.ceil(this.filtered().length / RESULTS_PER_PAGE)
        },

        // data source to fetch Quotes from
        url: QUOTES_URL,
    });

    // Construct a new Quote collection, Quotes.fetch() can be called
    // to populate
    var Quotes = new QuoteList;

    // View for a quote object
    var QuoteView = Backbone.View.extend({
        tagName:  "li",

        // Cache template elements
        template: _.template($('#quote-template').html()),

        render: function() {
            this.$el.html(this.template(this.model.toJSON()));
            return this;
        },
    });


    var AppView = Backbone.View.extend({
        el: $("#quoteapp"),

        statusTemplate: _.template($('#status-template').html()),

        events: {
            "click #paginate-next": "nextPage",
            "click #paginate-previous": "previousPage",
            "keyup #filter-keyword"  : "updateFilterKeyword",
            "change #filter-theme"  : "updateFilterTheme",
        },

        // Setup the view by fetching and rendering Quotes
        initialize: function() {
            this.listenTo(Quotes, 'sync', this.render);

            // store relevant elements
            this.main = $('#main');
            this.footer = $('.footer');
            this.filterKeyword = this.$("#filter-keyword");
            this.filterTheme = this.$("#filter-theme");
            this.quotesList = this.$("#quotes-list");

            // Load quote JSON from remote resource
            Quotes.fetch({ error: this.onFetchError });

            this.render();
            // this.footer.show();
        },

        // Scroll to top of page (i.e. when paging)
        scrollTop: function() {
            $("html, body").animate({ scrollTop: 0 }, 400);
        },

        // Increment Quotes page state and re-render
        nextPage: function() {
            Quotes.incrementPage(1);
            this.render();
            this.scrollTop();
        },

        // Decrement Quotes page state and re-render
        previousPage: function() {
            Quotes.incrementPage(-1);
            this.render();
            this.scrollTop();
        },

        // To avoid diffing the state of contents of the list, a
        // render simply clears and re-populates
        render: function() {
            var quotes = Quotes.visible();
            var totalPages = Quotes.totalPages();

            this.quotesList.empty();
            quotes.map(this.renderQuote)

            // Render the footer with correct pagination options
            this.footer.html(this.statusTemplate({
                currentPage: Math.min(Quotes.currentPage, totalPages),
                totalPages: totalPages,
            }));
        },

        updateFilterKeyword: function() {
            Quotes.updateFilterKeyword(this.filterKeyword.val());
            this.render();
        },

        updateFilterTheme: function() {
            Quotes.updateFilterTheme(this.filterTheme.val());
            this.render();
        },

        renderQuote: function(quote) {
            var view = new QuoteView({model: quote});
            this.$("#quotes-list").append(view.render().el);
        },

        // Handler if network call to fetch quotes fails
        onFetchError: function() {
            alert("Unable to load quotes from " + QUOTES_URL);
        },
    });

    var App = new AppView;
});
