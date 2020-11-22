import 'package:flutter/material.dart';
import 'package:tracking/components/custom_surfix_icon.dart';
import 'package:tracking/components/form_error.dart';
import 'body.dart';

import '../../../constants.dart';
import '../../../size_config.dart';

class UserForm extends StatefulWidget {
  final usernameCallback;
  final groupnameCallback;
  UserForm(this.usernameCallback, this.groupnameCallback);
  @override
  _UserFormState createState() => _UserFormState();
}

class _UserFormState extends State<UserForm> {
  final _formKey = GlobalKey<FormState>();
  String username;
  String groupname;
  final List<String> errors = [];
  final userNameController = TextEditingController();
  final groupNameController = TextEditingController();

  void addError({String error}) {
    if (!errors.contains(error))
      setState(() {
        errors.add(error);
      });
  }

  void removeError({String error}) {
    if (errors.contains(error))
      setState(() {
        errors.remove(error);
      });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          buildUserFormField(),
          SizedBox(height: getProportionateScreenHeight(30)),
          buildGroupFormField(),
          SizedBox(height: getProportionateScreenHeight(30)),
          FormError(errors: errors),
          SizedBox(height: getProportionateScreenHeight(20)),
        ],
      ),
    );
  }

  TextFormField buildGroupFormField() {
    return TextFormField(
      controller: groupNameController,
      // onSaved: (newValue) => groupname = newValue,
      onChanged: (value) {
        setState(() {
          groupname = groupNameController.text;
          widget.groupnameCallback(groupname);
        });
        if (value.isNotEmpty) {
          removeError(error: kPassNullError);
        }
        return null;
      },
      validator: (value) {
        if (value.isEmpty) {
          addError(error: kPassNullError);
          return "";
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: "Group Name",
        hintText: "Enter your group name",
        // If  you are using latest version of flutter then lable text and hint text shown like this
        // if you r using flutter less then 1.20.* then maybe this is not working properly
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    );
  }

  TextFormField buildUserFormField() {
    return TextFormField(
      // onSaved: (newValue) => username = newValue,
      controller: userNameController,
      onChanged: (value) {
        setState(() {
          username = userNameController.text;
          widget.usernameCallback(username);
        });
        if (value.isNotEmpty) {
          removeError(error: kEmailNullError);
        }
        return null;
      },
      validator: (value) {
        if (value.isEmpty) {
          addError(error: kEmailNullError);
          return "";
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: "Username",
        hintText: "Enter your username",
        // If  you are using latest version of flutter then lable text and hint text shown like this
        // if you r using flutter less then 1.20.* then maybe this is not working properly
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    );
  }
}
