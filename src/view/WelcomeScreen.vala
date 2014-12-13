namespace Envelope {

    private static Welcome welcome_instance = null;

    public class Welcome : Granite.Widgets.Welcome {

        public static new unowned Welcome get_default () {
            if (welcome_instance == null) {
                welcome_instance = new Welcome ();
            }

            return welcome_instance;
        }

        public Welcome () {
            base (_("Get your budget going"), _("Envelope could not find any account"));
            build_ui ();
            connect_signals ();
        }

        private void build_ui () {
            append ("add", "Add an account", "Create an account to record your transactions");
            append ("document-import", _("Import transactions"),
                _("Import from a QIF file obtained from another application"));
        }

        private void connect_signals () {
            activated.connect (item_activated);
        }

        private void item_activated (int index ) {
            switch (index) {
                case 0:
                    var dialog = new AddAccountDialog ();

                    dialog.account_created.connect ((account) => {
                        dialog.destroy ();
                    });

                    dialog.show_all ();
                    break;

                case 1:
                    // TODO import task
                    break;
            }
        }
    }
}
