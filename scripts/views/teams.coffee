define 'teamsView', ['jquery', 'underscore', 'view', 'renderTemplate', 'dataStore', 'navigationBar', 'metadataStore'], ($, _, View, renderTemplate, dataStore, navigationBar, metadataStore) ->
    class TeamsView extends View
        constructor: ->
            @$main = null

            @teams = []
            @identity = null

            @onUpdateTeamProfile = null
            @onCreateTeam = null
            @onChangeTeamEmail = null
            @onQualifyTeam = null

            @urlRegex = /^\/teams$/

        getTitle: ->
            "#{metadataStore.getMetadata 'event-title' } :: Teams"

        renderTeams: ->
            sortedTeams = _.sortBy @teams, 'createdAt'
            @$main.find('.themis-team-count').show().html renderTemplate 'team-count-partial', count: @teams.length

            $section = @$main.find 'section'
            $section.empty()

            $content = $('<ul></ul>').addClass 'themis-teams list-unstyled'
            for team in sortedTeams
                $content.append $('<li></li>').html renderTemplate 'team-profile-simplified-partial', identity: @identity, team: team
            $section.html $content

        present: ->
            @$main = $ '#main'

            $
                .when dataStore.getIdentity()
                .done (identity) =>
                    @identity = identity
                    navigationBar.present
                        identity: identity
                        active: 'teams'

                    @$main.html renderTemplate 'teams-view'
                    $section = @$main.find 'section'

                    dataStore.getTeams (err, teams) =>
                        if err?
                            $section.html $('<p></p>').addClass('lead text-danger').text err
                        else
                            @teams = teams
                            @renderTeams()

                            if dataStore.supportsRealtime()
                                dataStore.connectRealtime()

                                @onUpdateTeamProfile = (e) =>
                                    data = JSON.parse e.data
                                    team = _.findWhere @teams, id: data.id
                                    if team?
                                        team.country = data.country
                                        team.locality = data.locality
                                        team.institution = data.institution
                                        @renderTeams()

                                dataStore.getRealtimeProvider().addEventListener 'updateTeamProfile', @onUpdateTeamProfile

                                @onQualifyTeam = (e) =>
                                    data = JSON.parse e.data
                                    team = _.findWhere @teams, id: data.id
                                    if team?
                                        team.emailConfirmed = data.emailConfirmed
                                    else
                                        team = dataStore.createTeam data
                                        @teams.push team
                                    @renderTeams()

                                dataStore.getRealtimeProvider().addEventListener 'qualifyTeam', @onQualifyTeam

                                if _.contains ['admin', 'manager'], @identity.role
                                    @onCreateTeam = (e) =>
                                        data = JSON.parse e.data
                                        team = dataStore.createTeam data
                                        @teams.push team
                                        @renderTeams()

                                    dataStore.getRealtimeProvider().addEventListener 'createTeam', @onCreateTeam

                                    @onChangeTeamEmail = (e) =>
                                        data = JSON.parse e.data
                                        team = _.findWhere @teams, id: data.id
                                        if team?
                                            team.email = data.email
                                            team.emailConfirmed = data.emailConfirmed
                                            @renderTeams()

                                    dataStore.getRealtimeProvider().addEventListener 'changeTeamEmail', @onChangeTeamEmail

                .fail (err) =>
                    navigationBar.present()
                    @$main.html renderTemplate 'internal-error-view'

        dismiss: ->
            if dataStore.supportsRealtime()
                if @onUpdateTeamProfile?
                    dataStore.getRealtimeProvider().removeEventListener 'updateTeamProfile', @onUpdateTeamProfile
                    @onUpdateTeamProfile = null

                if @onCreateTeam?
                    dataStore.getRealtimeProvider().removeEventListener 'createTeam', @onCreateTeam
                    @onCreateTeam = null

                if @onChangeTeamEmail?
                    dataStore.getRealtimeProvider().removeEventListener 'changeTeamEmail', @onChangeTeamEmail
                    @onChangeTeamEmail = null

                if @onQualifyTeam?
                    dataStore.getRealtimeProvider().removeEventListener 'qualifyTeam', @onQualifyTeam
                    @onQualifyTeam = null

            @$main.empty()
            @$main = null
            @teams = []
            @identity = null
            navigationBar.dismiss()

    new TeamsView()
