define 'postProvider', ['jquery', 'underscore', 'dataStore', 'EventEmitter', 'metadataStore', 'postModel'], ($, _, dataStore, EventEmitter, metadataStore, PostModel) ->
    class PostProvider extends EventEmitter
        constructor: ->
            super()
            @posts = []

            @onCreate = null
            @onUpdate = null
            @onRemove = null

        getPosts: ->
            @posts

        subscribe: ->
            return unless dataStore.supportsRealtime()
            realtimeProvider = dataStore.getRealtimeProvider()

            @onCreate = (e) =>
                options = JSON.parse e.data
                post = new PostModel options
                @posts.push post
                @trigger 'createPost', [post]

            realtimeProvider.addEventListener 'createPost', @onCreate

            @onUpdate = (e) =>
                options = JSON.parse e.data
                post = new PostModel options
                ndx = _.findIndex @posts, id: options.id
                if ndx > -1
                    @posts.splice ndx, 1
                @posts.push post
                @trigger 'updatePost', [post]

            realtimeProvider.addEventListener 'updatePost', @onUpdate

            @onRemove = (e) =>
                options = JSON.parse e.data
                ndx = _.findIndex @posts, id: options.id
                if ndx > -1
                    @posts.splice ndx, 1
                    @trigger 'removePost', [options.id]

            realtimeProvider.addEventListener 'removePost', @onRemove

        unsubscribe: ->
            return unless dataStore.supportsRealtime()
            realtimeProvider = dataStore.getRealtimeProvider()

            if @onCreate
                realtimeProvider.removeEventListener 'createPost', @onCreate
                @onCreate = null

            if @onUpdate
                realtimeProvider.removeEventListener 'updatePost', @onUpdate
                @onUpdate = null

            if @onRemove
                realtimeProvider.removeEventListener 'removePost', @onRemove
                @onRemove = null

            @posts = []

        fetchPosts: ->
            promise = $.Deferred()
            url = "#{metadataStore.getMetadata 'domain-api' }/post/all"
            $.ajax
                url: url
                dataType: 'json'
                xhrFields:
                    withCredentials: yes
                success: (responseJSON, textStatus, jqXHR) =>
                    @posts = _.map responseJSON, (options) ->
                        new PostModel options
                    promise.resolve @posts
                error: (jqXHR, textStatus, errorThrown) ->
                    if jqXHR.responseJSON?
                        promise.reject jqXHR.responseJSON
                    else
                        promise.reject 'Unknown error. Please try again later.'

            promise

        removePost: (id, token) ->
            promise = $.Deferred()
            url = "#{metadataStore.getMetadata 'domain-api' }/post/#{id}/remove"
            $.ajax
                url: url
                type: 'POST'
                dataType: 'json'
                data: {}
                xhrFields:
                    withCredentials: yes
                headers: { 'X-CSRF-Token': token }
                success: (responseJSON, textStatus, jqXHR) ->
                    promise.resolve()
                error: (jqXHR, textStatus, errorThrown) ->
                    if jqXHR.responseJSON?
                        promise.reject jqXHR.responseJSON
                    else
                        promise.reject 'Unknown error. Please try again later.'


    new PostProvider()