define 'contestProvider', ['jquery', 'underscore', 'EventEmitter', 'dataStore', 'metadataStore', 'contestModel', 'teamScoreModel', 'teamProvider', 'teamTaskProgressModel', 'identityProvider'], ($, _, EventEmitter, dataStore, metadataStore, ContestModel, TeamScoreModel, teamProvider, TeamTaskProgressModel, identityProvider) ->
    class ContestProvider extends EventEmitter
        constructor: ->
            super()
            @contest = null
            @teamScores = []
            @teamTaskProgressEntries = []

            @onUpdate = null
            @onUpdateTeamScore = null
            @onQualifyTeam = null

            @onCreateTeamTaskProgress = null

        getContest: ->
            @contest

        getTeamScores: ->
            @teamScores

        getTeamTaskProgressEntries: ->
            @teamTaskProgressEntries

        subscribe: ->
            return unless dataStore.supportsRealtime()
            realtimeProvider = dataStore.getRealtimeProvider()

            @onUpdate = (e) =>
                options = JSON.parse e.data
                @contest = new ContestModel options
                @trigger 'updateContest', [@contest]

            realtimeProvider.addEventListener 'updateContest', @onUpdate

            @onUpdateTeamScore = (e) =>
                options = JSON.parse e.data
                teamScore = new TeamScoreModel options
                ndx = _.findIndex @teamScores, teamId: options.teamId
                if ndx > -1
                    @teamScores.splice ndx, 1
                @teamScores.push teamScore
                @trigger 'updateTeamScore', [teamScore]

            realtimeProvider.addEventListener 'updateTeamScore', @onUpdateTeamScore

            @onQualifyTeam = (team) =>
                ndx = _.findIndex @teamScores, teamId: team.id
                if ndx == -1
                    teamScore = new TeamScoreModel
                        teamId: team.id
                        score: 0
                        updatedAt: null
                    @teamScores.push teamScore
                    @trigger 'updateTeamScore', [teamScore]

            teamProvider.on 'qualifyTeam', @onQualifyTeam

            identity = identityProvider.getIdentity()
            if identity.role is 'team'
                @onCreateTeamTaskProgress = (e) =>
                    options = JSON.parse e.data
                    teamTaskProgress = new TeamTaskProgressModel options
                    ndx = _.findIndex @teamTaskProgressEntries, teamId: options.teamId, taskId: options.taskId
                    if teamTaskProgress.teamId == identity.id and ndx == -1
                        @teamTaskProgressEntries.push teamTaskProgress
                        @trigger 'createTeamTaskProgress', [teamTaskProgress]

                realtimeProvider.addEventListener 'createTeamTaskProgress', @onCreateTeamTaskProgress, false

        unsubscribe: ->
            return unless dataStore.supportsRealtime()
            realtimeProvider = dataStore.getRealtimeProvider()

            if @onUpdate?
                realtimeProvider.removeEventListener 'updateContest', @onUpdate
                @onUpdate = null

            if @onUpdateTeamScore?
                realtimeProvider.removeEventListener 'updateTeamScore', @onUpdateTeamScore
                @onUpdateTeamScore = null

            if @onQualifyTeam?
                teamProvider.off 'qualifyTeam', @onQualifyTeam
                @onQualifyTeam = null

            if @onCreateTeamTaskProgress?
                realtimeProvider.removeEventListener 'createTeamTaskProgress', @onCreateTeamTaskProgress
                @onCreateTeamTaskProgress = null

            @contest = null
            @teamScores = []
            @teamTaskProgressEntries = []

        fetchContest: ->
            promise = $.Deferred()
            url = "#{metadataStore.getMetadata 'domain-api' }/contest"
            $.ajax
                url: url
                dataType: 'json'
                xhrFields:
                    withCredentials: yes
                success: (responseJSON, textStatus, jqXHR) =>
                    @contest = new ContestModel responseJSON
                    promise.resolve @contest
                error: (jqXHR, textStatus, errorThrown) ->
                    if jqXHR.responseJSON?
                        promise.reject jqXHR.responseJSON
                    else
                        promise.reject 'Unknown error. Please try again later.'

            promise

        fetchTeamScores: ->
            promise = $.Deferred()

            url = "#{metadataStore.getMetadata 'domain-api' }/contest/scores"
            $.ajax
                url: url
                dataType: 'json'
                xhrFields:
                    withCredentials: yes
                success: (responseJSON, textStatus, jqXHR) =>
                    @teamScores = _.map responseJSON, (options) ->
                        new TeamScoreModel options
                    promise.resolve @teamScores
                error: (jqXHR, textStatus, errorThrown) ->
                    if jqXHR.responseJSON?
                        promise.reject jqXHR.responseJSON
                    else
                        promise.reject 'Unknown error. Please try again later.'

            promise

        fetchTeamTaskProgressEntries: ->
            promise = $.Deferred()

            identity = identityProvider.getIdentity()
            if _.contains ['admin', 'manager'], identity.role
                url = "#{metadataStore.getMetadata 'domain-api' }/contest/progress"
            else if identity.role is 'team'
                url = "#{metadataStore.getMetadata 'domain-api' }/contest/team/#{identity.id}/progress"
            else
                promise.reject 'Unknown error. Please try again later.'

            if _.contains ['admin', 'manager', 'team'], identity.role
                $.ajax
                    url: url
                    dataType: 'json'
                    xhrFields:
                        withCredentials: yes
                    success: (responseJSON, textStatus, jqXHR) =>
                        @teamTaskProgressEntries = _.map responseJSON, (options) ->
                            new TeamTaskProgressModel options
                        promise.resolve @teamTaskProgressEntries
                    error: (jqXHR, textStatus, errorThrown) ->
                        if jqXHR.responseJSON?
                            promise.reject jqXHR.responseJSON
                        else
                            promise.reject 'Unknown error. Please try again later.'

            promise

    new ContestProvider()
