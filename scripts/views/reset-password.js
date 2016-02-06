import $ from 'jquery'
import View from './base'
import renderTemplate from '../utils/render-template'
import dataStore from '../data-store'
import navigationBar from '../navigation-bar'
import metadataStore from '../utils/metadata-store'
import identityProvider from '../providers/identity'
import History from 'jquery.history'
import 'parsley'
import 'jquery.form'


class ResetPasswordView extends View {
  constructor() {
    this.$main = null
    this.urlRegex = /^\/reset-password$/
  }

  getTitle() {
    return `${metadataStore.getMetadata('event-title')} :: Reset password`
  }

  present() {
    this.$main = $('#main')

    $
      .when(identityProvider.fetchIdentity())
      .done((identity) => {
        identityProvider.subscribe()
        navigationBar.present()

        this.$main.html(renderTemplate('reset-password-view', { identity: identity }))

        let $form = this.$main.find('form.themis-form-reset')
        $form.parsley()
        let $submitError = $form.find('.submit-error > p')
        let $submitButton = $form.find('button')

        let $successAlert = this.$main.find('div.themis-reset-success')
        let $errorAlert = this.$main.find('div.themis-reset-error')

        let urlParams = History.getState().data.params
        if (urlParams.team && urlParams.code) {
          $form.show()

          $form.on('submit', (e) => {
            e.preventDefault()
            $form.ajaxSubmit({
              beforeSubmit: () => {
                $submitError.text('')
                $submitButton.prop('disabled', true)
              },
              clearForm: true,
              dataType: 'json',
              data: {
                team: urlParams.team,
                code: urlParams.code
              },
              xhrFields: {
                withCredentials: true
              },
              headers: {
                'X-CSRF-Token': identityProvider.getIdentity().token
              },
              success: (responseText, textStatus, jqXHR) => {
                $form.hide()
                $successAlert.show()
              },
              error: (jqXHR, textStatus, errorThrown) => {
                if (jqXHR.responseJSON) {
                  $submitError.text(jqXHR.responseJSON)
                } else {
                  $submitError.text('Unknown error. Please try again later.')
                }
              },
              complete: () => {
                $submitButton.prop('disabled', false)
              }
            })
          })
        } else {
          $errorAlert.show()
        }
      .fail((err) => {
        navigationBar.present()
        this.$main.html(renderTemplate('internal-error-view'))
      })
  }

  dismiss() {
    identityProvider.unsubscribe()
    this.$main.empty()
    this.$main = null
    navigationBar.dismiss()
  }
}


export default new ResetPasswordView()
