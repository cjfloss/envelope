namespace Envelope {
    public class Welcome : Granite.Widgets.Welcome {

        public Welcome () {
            base (_("Get your budget going"), _("Envelope could not find any account"));
            build_ui ();
            connect_signals ();
        }

        private void build_ui () {
            append ("add", "Add an account", "Create an account to record your transactions");
        }

        private void connect_signals () {
            activated.connect (item_activated);
        }

        private void item_activated (int index ) {
            switch (index) {
                case 0:
                    var dialog = new AddAccountDialog ();
                    dialog.account_created.connect (s_account_created);
                    dialog.show_all ();
                    break;
            }
        }

        private void s_account_created (Account account) {
            Envelope.App.main_window.sidebar.s_account_created (account);
            Envelope.App.main_window.sidebar.list_account_selected (account);
        }

    }
}
