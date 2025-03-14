import 'package:facerecognition_flutter/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'model/person.dart';
import 'main.dart';

class PersonView extends StatefulWidget {
  final List<Person> personList;
  final MyHomePageState homePageState;

  const PersonView({
    super.key,
    required this.personList,
    required this.homePageState,
  });

  @override
  _PersonViewState createState() => _PersonViewState();
}

class _PersonViewState extends State<PersonView> {
  deletePerson(int index) async {
    try {
      await widget.homePageState.deletePerson(index);
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.personList.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildPersonItem(index);
      },
    );
  }

  Widget _buildPersonItem(int index) {
    final person = widget.personList[index];

    return Dismissible(
      key: Key(person.name),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_forever_rounded,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (direction) => deletePerson(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Material(
          borderRadius: BorderRadius.circular(16),
          elevation: 1,
          color: ColorUtils.blackbg,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {},
            splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Hero(
                    tag: person.name,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: MemoryImage(person.faceJpg),
                      onBackgroundImageError: (exception, stackTrace) =>
                          const Icon(Icons.person_rounded),
                      child: person.faceJpg.isEmpty
                          ? Icon(
                              Icons.person_rounded,
                              size: 28,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          person.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => deletePerson(index),
                    style: IconButton.styleFrom(
                      hoverColor: Theme.of(context).colorScheme.errorContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
