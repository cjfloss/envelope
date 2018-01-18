using Envelope.Service;
using Gee;

namespace Envelope.Tests.Service.Importer.QIF {
    public void test_import_success () {
        try {
            ArrayList<Transaction>? transactions = QIFImporter.get_default ().import (test_data_path ("sample.qif"));

            assert_nonnull (transactions);
            assert_true (transactions.size == 29);
        } catch (ServiceError err) {
            Test.fail ();
        } catch (ImporterError err) {
            Test.fail ();
        }
    }

    public void test_import_file_not_found () {
        try {
            ArrayList<Transaction>? transactions = QIFImporter.get_default ().import (test_data_path ("enoent"));
            Test.fail ();
        } catch (ServiceError err) {
            assert (err is ServiceError.ENOENT);
        } catch (ImporterError err) {
            Test.fail ();
        }
    }

    private string test_data_path (string filename) {
        return Test.build_filename (Test.FileType.DIST, "data", filename);
    }
}

void main (string[] args) {
    Test.init (ref args);

    Test.add_func ("/envelope/service/importer/qif/success",
        Envelope.Tests.Service.Importer.QIF.test_import_success);

    Test.add_func ("/envelope/service/importer/qif/file_not_found",
        Envelope.Tests.Service.Importer.QIF.test_import_file_not_found);

    Test.run ();
}
