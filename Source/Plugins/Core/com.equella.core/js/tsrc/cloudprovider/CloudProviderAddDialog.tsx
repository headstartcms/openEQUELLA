import * as React from "react";
import {
  Button,
  createStyles,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
  TextField,
  Theme,
  Typography,
  WithStyles,
  withStyles
} from "@material-ui/core";
import { cloudProviderLangStrings } from "./CloudProviderModule";
import { commonString } from "../util/commonstrings";
import Link from "@material-ui/core/Link";
import CloudProviderDisclaimerDialog from "./CloudProviderDisclaimerDialog";

const styles = (theme: Theme) =>
  createStyles({
    disclaimerText: {
      marginTop: theme.spacing.unit
    },
    link: {
      cursor: "pointer"
    }
  });

interface CloudProviderAddDialogProps extends WithStyles<typeof styles> {
  open: boolean;
  onCancel: () => void;
  onRegister: (url: string) => void;
}
interface CloudProviderAddDialogState {
  cloudProviderUrl: string;
  disclaimerDialogOpen: boolean;
}

class CloudProviderAddDialog extends React.Component<
  CloudProviderAddDialogProps,
  CloudProviderAddDialogState
> {
  constructor(props: CloudProviderAddDialogProps) {
    super(props);
    this.state = {
      cloudProviderUrl: "",
      disclaimerDialogOpen: false
    };
  }

  handleTextChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    this.setState({
      cloudProviderUrl: e.target.value
    });
  };

  validateUrl = (): boolean => {
    let url = this.state.cloudProviderUrl;
    if (url == "") {
      return true;
    } else {
      return url.search(/^[Hh][Tt][Tt][Pp]([Ss]?):\/\//) == 0;
    }
  };

  openDisclaimerDialog = () => {
    this.setState({
      disclaimerDialogOpen: true
    });
  };

  closeDisclaimerDialog = () => {
    this.setState({
      disclaimerDialogOpen: false
    });
  };

  render() {
    const { open, onCancel, onRegister, classes } = this.props;
    const { cloudProviderUrl, disclaimerDialogOpen } = this.state;
    let isUrlValid = this.validateUrl();
    return (
      <div>
        <Dialog
          open={open}
          onClose={onCancel}
          aria-labelledby="form-dialog-title"
          disableBackdropClick={true}
          disableEscapeKeyDown={true}
          fullWidth
        >
          <DialogTitle>
            {cloudProviderLangStrings.newcloudprovider.title}
          </DialogTitle>
          <DialogContent>
            <DialogContentText>
              {cloudProviderLangStrings.newcloudprovider.text}
            </DialogContentText>
            <TextField
              autoFocus
              margin="dense"
              id="new_cloud_provider_url"
              label={cloudProviderLangStrings.newcloudprovider.label}
              value={cloudProviderUrl}
              required
              fullWidth
              onChange={this.handleTextChange}
              error={!isUrlValid}
              helperText={cloudProviderLangStrings.newcloudprovider.help}
            />

            <Typography variant="body2" className={classes.disclaimerText}>
              {cloudProviderLangStrings.newcloudprovider.disclaimer.text}
              <Link
                className={classes.link}
                underline="always"
                onClick={this.openDisclaimerDialog}
              >
                <b>
                  {cloudProviderLangStrings.newcloudprovider.disclaimer.title}
                </b>
              </Link>
            </Typography>
          </DialogContent>
          <DialogActions>
            <Button id="cancel-register" onClick={onCancel} color="primary">
              {commonString.action.cancel}
            </Button>
            <Button
              id="confirm-register"
              onClick={() => {
                onRegister(cloudProviderUrl);
              }}
              color="primary"
              disabled={!cloudProviderUrl || !isUrlValid}
            >
              {commonString.action.register}
            </Button>
          </DialogActions>
        </Dialog>

        <CloudProviderDisclaimerDialog
          openDialog={disclaimerDialogOpen}
          onClose={this.closeDisclaimerDialog}
        />
      </div>
    );
  }
}

export default withStyles(styles)(CloudProviderAddDialog);